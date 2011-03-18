require 'sinatra/base'
require 'fileutils'
require 'nokogiri'
require 'open-uri'

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
    attr_reader :storage_dir

    def initialize(opts={}, &block)
      p "ConfigServer::InstanceConfigs::initialize(#{opts})"
      @storage_dir = opts[:storage_dir]
      @validator = validator(opts[:instance_config_rng])
      ensure_storage_dir

      yield self if block_given?
      self
    end

    def exists?(uuid)
      puts "ConfigServer::InstanceConfigs::exists?(#{uuid})"
      dir_exists?(uuid)
    end

    def get(uuid)
      puts "ConfigServer::InstanceConfigs::get(#{uuid})"
      return exists?(uuid) ? get_data(uuid) : ""
    end

    def delete(uuid)
      if dir = get_path_if_exists(uuid)
        FileUtils.rm_rf(dir)
      end
    end

    def create(uuid, data)
      create_configs(uuid, data)
    end

    def update(uuid, params={})
      update_provided_params(uuid, params)
    end

    private

    def validator(rng_file)
      Nokogiri::XML::RelaxNG(open(rng_file))
    end

    def ensure_storage_dir
      puts "ConfigServer::InstanceConfigs::ensure_home_dir"
      instances_home = @storage_dir + '/instances'
      deployables_home = @storage_dir + '/deployables'
      FileUtils.mkdir_p(@storage_dir) if not File.directory?(@storage_dir)
      FileUtils.mkdir_p(instances_home) if not File.directory?(instances_home)
      FileUtils.mkdir_p(deployables_home) if not File.directory?(deployables_home)
    end

    def get_instance_path(uuid)
      puts "ConfigServer::InstanceConfigs::get_instance_path(#{uuid})"
      @storage_dir + '/instances/' + uuid
    end

    def dir_exists?(uuid)
      puts "ConfigServer::InstanceConfigs::dir_exists?(#{uuid})"
      File.directory?(get_instance_path(uuid))
    end

    def get_path_if_exists(uuid)
      dir = get_instance_path(uuid)
      return dir if File.directory?(dir)
    end

    def create_dir(uuid)
      if dir = get_instance_path(uuid)
        Dir.mkdir(dir)
      end
    end

    def get_data(uuid)
      puts "ConfigServer::InstanceConfigs::get_data?(#{uuid})"
      response = "<config-response>\n"
      dir = get_instance_path(uuid)
      # 1) get the list of provided-parameters for the client
      #    these are the list of params the config server is still waiting on
      provided_params = File.open(dir + '/provided-parameters.xml') do |f|
        Nokogiri::XML(f)
      end if File.exists?(dir + '/provided-parameters.xml')
      # report only the provided-params without values
      response += "  <provided-parameters>\n"
      provided_params.xpath('//provided-parameter[not(value)]').each do |p|
        response += "    <provided-parameter name='#{p['name']}'/>\n"
      end if not provided_params.nil?
      response += "  </provided-parameters>\n"

      # 2) get the node.yaml if we can
      yaml_file = dir + '/node.yaml'
      if File.exists?(yaml_file)
        yaml = IO.read(yaml_file)
        response += "  <config-data><![CDATA[#{yaml}]]></config-data>\n"
      end

      response += "</config-response>\n"
    end

    def create_configs(uuid, data)
      create_dir(uuid) if not dir_exists?(uuid)
      replace_configs(uuid, data)
    end

    def validate(uuid, data)
      # A no-op method for now
      # Eventually, this will validate against a RelaxNG schema
      config = Nokogiri::XML(data)
      errors = @validator.validate(config)
      if errors.size > 0
        raise InvalidInstanceConfigError.new(errors),
            "The provided instance config for #{uuid} is not a valid " +
            "instance-config document."
      end
      return config
    end

    def replace_configs(uuid, data)
      # wipe and replace
      # validate the data as instance-config.xml data
      config = validate(uuid, data)
      dir = get_instance_path(uuid)
      parse_and_update(dir, uuid, config)
    end

    def parse_and_update(dir, uuid, config)
      # 1) write the entire configs out to the instance-config.xml
      File.open(dir + '/instance-config.xml', 'w') do |f|
        # capture the instance config data exactly as it was provided
        config.write_xml_to(f)
      end

      # 2) parse and write the provided param data (if provided params exist)
      provided_params = config.xpath('//provided-parameter')
      if not provided_params.empty?
        File.open(dir + '/provided-parameters.xml', 'w') do |f|
          f.write("<provided-parameters>\n")
          provided_params.each do |p|
            f.write("  <provided-parameter name='#{p['name']}'/>\n")
          end
          f.write("</provided-parameters>\n")
        end
      end

      # 3) parse and write the required param data (if required params exist)
      required_params = config.xpath('//parameter/reference/..')
      # grab all parameter nodes with a reference not as a child
      if not required_params.empty?
        File.open(dir + '/required-parameters.xml', 'w') do |f|
          f.write("<required-parameters>\n")
          required_params.each do |p|
            f.write("  <required-parameter name='#{p['name']}' ")
            ref = p.xpath('./reference')[0]
            f.write(" assembly='#{ref['assembly']}'")
            f.write(" parameter='#{ref['provided-parameter']}'/>\n")
          end
          f.write("</required-parameters>\n")
        end
      end

      # 4) create and write the node yaml (if possible)
      if required_params.empty?
        # only write the node.yaml if there are no required params to wait for
        write_node_yaml(dir, uuid, config)
      end
    end

    # Writes the node.yaml file if the required-parameters have all been met.
    # If the file can be written, returns true.  Returns false otherwise.
    def write_node_yaml(dir, uuid, config)
      required_params = File.open(dir + '/required-parameters.xml', 'r') do |f|
        Nokogiri::XML(f)
      end if File.exists?(dir + '/required-parameters.xml')

      ## make sure that all required-parameter nodes have a "value" child node
      if required_params.nil? or
          required_params.xpath('//required-parameter[not(value)]').empty?
        # yaml is built from the instance-config ("config") and from the
        # required-parameters that have been fully populated at this point
        yaml =  "---\n"
        yaml += "classes:\n"
        config.xpath('//services/puppet/class').each do |c|
          yaml += "    - #{c['name']}\n"
        end
        yaml += "parameters:\n"
        #FIXME: only handles scalar values
        config.xpath('//services/puppet/parameter/value/..').each do |p|
          yaml += "    #{p['name']}: #{p.first_element_child.content}\n"
        end
        #FIXME: only handles scalar values
        required_params.xpath('//required-parameter/value/..').each do |p|
          yaml += "    #{p['name']}: #{p.first_element_child.content}\n"
        end if not required_params.nil?
        File.open(dir + '/node.yaml', 'w') do |f|
          f.write(yaml)
        end
        return true
      end
      return false
    end


    def update_provided_params(uuid, params={})
      puts "ConfigServer::InstanceConfigs#update_provided_params(#{uuid}, #{params.inspect})"
      dir = get_instance_path(uuid)
      provided_params = File.open(dir + '/provided-parameters.xml') do |f|
        Nokogiri::XML(f)
      end if File.exists?(dir + '/provided-parameters.xml')
      params.each do |k,v|
        param = provided_params.xpath("//provided-parameter[@name='#{k}']")[0]
        param.inner_html = "<value><![CDATA[#{v}]]></value>" if not param.nil?
      end if not (params.nil? or params.empty?)
      File.open(dir + '/provided-parameters.xml', 'w') do |f|
        provided_params.write_xml_to(f)
      end

      instance_config = File.open(dir + '/instance-config.xml') do |f|
        Nokogiri::XML(f)
      end if File.exists?(dir + '/instance-config.xml')
      deployable_id = instance_config.xpath('string(//deployable/@id)')
      update_dependent_params(deployable_id)
    end

    def update_dependent_params(deployable)
      # Waiting for the grand refactoring to implement this
    end
  end

  class DeployableConfigs
    attr_reader :storage_dir

    def initialize(opts={}, &block)
      p "ConfigServer::InstanceConfigs::initialize(#{opts})"
      @storage_dir = opts[:storage_dir]
      @validator = validator(opts[:instance_config_rng])
      ensure_storage_dir

      yield self if block_given?
      self
    end
  end
end
