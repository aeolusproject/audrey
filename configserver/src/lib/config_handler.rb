#
#   Copyright [2011] [Red Hat, Inc.]
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#  limitations under the License.
#
require 'sinatra/base'
require 'fileutils'
require 'nokogiri'
require 'open-uri'

require 'lib/model'

class String
  require 'base64'
  def to_b64
    Base64.encode64(self).delete("\n")
  end
  alias b64_encode to_b64

  def b64_decode
    Base64.decode64(self)
  end
end

module ConfigServer

  # There is a silly conventions used in this class.  Everywhere that "data" is
  # passed as argument to a method, it's assumed that it hasn't been validated
  # yet.  If it's called "config", then it has been validated.  To be validated
  # simply means that the "data" was validated against a RelaxNG schema.

  class InstanceConfigs
    attr_reader :version
    def initialize(settings)
      @settings = settings
      @logger = $LOGGER
      @version = @settings.version || "0.2.0"
    end

    def exists?(uuid)
      Model::Instance.exists?(uuid)
    end

    def deployment_exists?(uuid)
      Model::Deployable.exists?(uuid)
    end

    def get_configs(uuid)
      if exists?(uuid)
        instance = Model::Instance.find(uuid)
        configs = 
            services = instance.services
            log "uuid: #{uuid}"
            log "services: #{services.inspect}"
            "|" +
            services.map do |svc_name,params|
              "service|#{svc_name}" +
              if not params.empty?
                "|parameters|" +
                params.map do |p_name,value|
                  "#{p_name}&" + [value].pack("m0").delete("\n")
                end.join("|")
              else
                ""
              end
            end.join("|") +
            "|"
        return configs, instance.required_parameters_remaining?
      end
    end

    def get_provides(uuid, options={})
      options[:as] ||= :text
      if exists?(uuid)
        instance = Model::Instance.find(uuid)
        parameters = instance.provided_parameters(:only_empty => true)
        process_provides(parameters)
      end
    end

    def get_ip(uuid)
      Model::Instance.find(uuid).ip if exists?(uuid)
    end

    def delete_deployment(uuid)
      Model::Deployable.find(uuid).delete!
    end

    def create(uuid, data)
      xml = Model::Instance.validate(uuid, data)
      instance = Model::Instance.new(uuid, xml)
      register_with_oauth(instance)
    end

    def update(uuid, data, ip)
      return nil if not exists?(uuid)
      log "update #{uuid} with #{ip} and #{data}"

      instance = Model::Instance.find(uuid)
      instance.ip = ip

      params = parse_audrey_data(data)
      instance.provided_parameters_values = params

      provided_params = instance.provided_parameters(
        :only_with_values => true,
        :include_values => true)
      log "provided_params: #{provided_params.inspect}"

      dep = instance.deployable
      assembly_identifiers = [instance.uuid, instance.assembly_name]
      dep.instances_with_assembly_dependencies(assembly_identifiers).each do |uuid|
        log "found a dependency"
        other = Model::Instance.find(uuid)
        params = {}
        required_params = other.required_parameters
        log "required_params: #{required_params.to_xml}"
        match_string = assembly_identifiers.map {|id| "(@assembly='#{id}')"}.join("or")
        required_params.xpath("//required-parameter[#{match_string}]").each do |p|
          log "found a required param match: #{p.to_xml}"
          if provided_params.key?(p['parameter'])
            params[p['name']] = provided_params[p['parameter']]
          end
        end
        other.required_parameters_values = params if not params.empty?
      end

      parameters = instance.provided_parameters(:only_empty => true)
      process_provides(parameters)
    end

    def get_file(uuid)
      if exists?(uuid)
        instance = Model::Instance.find(uuid)
        instance.file
      end
    end

    def save_file(uuid, file)
      if exists?(uuid)
        instance = Model::Instance.find(uuid)
        instance.file = file
      end
    end

    private
    def logger
      @logger
    end

    def log(msg)
      logger.info msg
    end

    def parse_audrey_data(data)
      return {} if data.nil? or "|&|" == data
      log "parse_audrey_data(#{data})"
      (data.split "|").map do |d|
        next if d.nil? or d.empty?
        k, v = d.split "&"
        # the value for "k" can be nil if the audrey-agent hasn't been able to
        # collect this value yet
        if v
          {k => v.b64_decode}
        end
      end.compact.inject(:merge)
    end

    def process_provides(provides)
      "|" + provides.join('&') + "|"
    end

    def register_with_oauth(instance)
      username = instance.uuid
      if secret = instance.secret
        Model::Consumer.create(username, secret)
      end
    end
  end
end
