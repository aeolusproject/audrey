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
    def initialize(version="0.0.3")
      @version = version
    end

    def exists?(uuid)
      Model::Instance.exists?(uuid)
    end

    def get_configs(uuid, options={})
      options[:as] ||= :text

      if exists?(uuid)
        instance = Model::Instance.find(uuid)
        configs = case options[:as]
          when :xml
            "<node-config ver='#{@version}'>\n" +
            instance.services.map do |s|
              s[:classes].map {|c| "  <class name='#{c}'>"}.join("\n") +
              "\n" +
              s[:parameters].map do |p|
                "  <parameter name='#{p['name']}'>\n" +
                "    <value><![CDATA[#{p['value']}'></value>\n" +
                "  </parameter>"
              end.join("\n")
            end.join +
            "\n</node-config>\n"
          when :text
            classes, params = instance.services(:flat => true)
            "|classes" +
            classes.map {|c| "&#{c}"}.join +
            "|parameters" +
            params.map do |p|
              value = p[1].to_s
              "|#{p[0]}&#{value.to_b64}"
            end.join + "|"
          else
            ""
        end
      end
      return configs
    end

    def get_provides(uuid, options={})
      options[:as] ||= :text
      if exists?(uuid)
        instance = Model::Instance.find(uuid)
        parameters = instance.provided_parameters(:only_empty => true)
        process_provides(parameters, options)
      end
    end

    def delete(uuid)
      Model::Instance.find(uuid).delete! if exists?(uuid)
    end

    def create(uuid, data)
      Model::Instance.new(uuid, data)
    end

    def update(uuid, data, options={})
      return nil if not exists?(uuid)

      params = parse_audrey_data(data)
      instance = Model::Instance.find(uuid)
      instance.provided_parameters_values = params

      provided_params = instance.provided_parameters(
        :only_with_values => true,
        :include_values => true)
      puts "provided_params: #{provided_params.inspect}"

      dep = instance.deployable
      asy = instance.assembly_name
      dep.instances_with_assembly_dependencies(asy).each do |uuid|
        puts "found a dependency"
        other = Model::Instance.find(uuid)
        params = {}
        required_params = other.required_parameters(:raw => true)
        puts "required_params: #{required_params.to_xml}"
        required_params.xpath("//required-parameter[@assembly='#{asy}']").each do |p|
          puts "found a required param match: #{p.to_xml}"
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

    private
    def parse_audrey_data(data)
      return {} if data.nil?
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
  end
end
