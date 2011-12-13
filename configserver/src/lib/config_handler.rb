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

  class InvalidInstanceConfigError < StandardError
    attr_reader :errors

    def initialize(errors = nil)
      @errors = errors
    end
  end

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

    def get_configs(uuid, options={})
      options[:as] ||= :text

      if exists?(uuid)
        instance = Model::Instance.find(uuid)
        configs = case options[:as]
          when :xml
            "<node-config ver='#{@version}'>\n" +
            "  <services>\n" +
            instance.services.map do |name, params|
              "    <service name='#{name}'>\n" +
              "      <parameters>\n" +
              params.map do |pname, val|
                "        <parameter name='#{pname}'>\n" +
                "          <value><![CDATA[#{val}]]></value>\n" +
                "        </parameter>"
              end.join("\n") +
              "\n" +
              "      </parameters>\n" +
              "    </service>\n"
            end.join +
            "  </services>\n" +
            "</node-config>\n"
          when :text
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
          when :textold
            #old format for now
            #|classes&service_name&service_name|parameters|param1&b64(va11)|param2&b64(val2)|
            #new format soon
            #|service&<s1>|parameters|<p1name>&b64(<v1>)|<p2name>&b64(<v2>)|service&<s2>|parameters|<p1name>&b64(<v1>)|<p2name>&b64(<v2>)|
            "|classes&" +
	    instance.services.keys.join("&") +
            "|parameters|" +
            instance.services.values.map do |params|
              params.map do |pname, val|
                "#{pname}&" + [val].pack("m0").delete("\n")
              end.join("|")
            end.join("|") +
            "|"
          else
            ""
        end
        return configs, instance.required_parameters_remaining?
      end
    end

    def get_provides(uuid, options={})
      options[:as] ||= :text
      if exists?(uuid)
        instance = Model::Instance.find(uuid)
        parameters = instance.provided_parameters(:only_empty => true)
        process_provides(parameters, options)
      end
    end

    def get_ip(uuid, options={})
      Model::Instance.find(uuid).ip if exists?(uuid)
    end

    def delete(uuid)
      Model::Instance.find(uuid).delete! if exists?(uuid)
    end

    def delete_deployment(uuid)
      Model::Deployable.find(uuid).delete!
    end

    def create(uuid, data)
      xml = Model::Instance.validate(uuid, data)
      instance = Model::Instance.new(uuid, xml)
      register_with_oauth(instance)
    end

    def update(uuid, data, ip, options={})
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
        required_params = other.required_parameters(:raw => true)
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

      options[:as] ||= :text
      parameters = instance.provided_parameters(:only_empty => true)
      process_provides(parameters, options)
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
        {k => v.b64_decode}
      end.compact.inject(:merge)
    end

    def process_provides(provides, opts={})
      case opts[:as]
        when :xml
          "<parameters>\n" +
          provides.map do |p|
            "  <parameter name='#{p}'/>"
          end.join("\n") +
          "\n</parameters>"
        when :text
          "|" + provides.join('&') + "|"
        else
          ""
      end
    end

    def register_with_oauth(instance)
      username = instance.uuid
      if secret = instance.secret
        Model::Consumer.create(username, secret)
      end
    end
  end
end
