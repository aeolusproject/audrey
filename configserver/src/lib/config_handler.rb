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
      @version = @settings.version || "0.2.0"
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
            puts "uuid: #{uuid}"
            puts "services: #{services.inspect}"
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

    def get_ip(uuid, options={})
      Model::Instance.find(uuid).ip if exists?(uuid)
    end

    def delete(uuid)
      Model::Instance.find(uuid).delete! if exists?(uuid)
    end

    def create(uuid, data)
      xml = Model::Instance.validate(uuid, data)
      instance = Model::Instance.new(uuid, xml)
      register_with_proxy(instance)
    end

    def update(uuid, data, ip, options={})
      return nil if not exists?(uuid)

      instance = Model::Instance.find(uuid)
      instance.ip = ip

      params = parse_audrey_data(data)
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
    def parse_audrey_data(data)
      puts "parse_audrey_data(#{data})"
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

    def register_with_proxy(instance)
      if "apache" == @settings.proxy_type
        username = instance.uuid
        if password = instance.password
          File.open(@settings.proxy_auth_file, File::WRONLY|File::APPEND) do |f|
            f.puts "#{username}:#{password}"
          end if File.exists?(@settings.proxy_auth_file)
        end
      end
    end
  end
end
