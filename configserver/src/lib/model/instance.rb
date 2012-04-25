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
require 'fileutils'
require 'tmpdir'
require 'nokogiri'
require 'open-uri'

require 'net/http'
require 'net/https'

require 'active_support/ordered_hash'

require 'zlib'
require 'archive/tar/minitar'
include Archive::Tar

require 'lib/model/base'
require 'lib/model/service'

class Dir
  class << self
    @@dirstack = []
    def pushd(dir, &block)
      @@dirstack.unshift(Dir.pwd)
      Dir.chdir(dir)
      if block_given?
        yield
        popd
      end
      return @@dirstack
    end
    def popd
      Dir.chdir(@@dirstack.shift) unless @@dirstack.empty?
      return @@dirstack
    end
  end
end

module ConfigServer
  module Model
    class InvalidInstanceConfigError < StandardError
      attr_reader :errors
      attr_reader :cause
      attr_reader :message

      def initialize(errors=nil, cause=nil)
        @errors = (errors.nil?) ? [] : errors
        if not @errors.is_a? Array
          @errors = [@errors]
        end
        @message = errors
        @cause = cause if not cause.nil?
      end

      def to_s
        s = super()
        @errors.each do |error|
          s = "#{s}\n  Error: #{error}"
        end
        s
      end
    end

    def self.instance_config_schema_location=(location)
      @intance_config_schema_location = location
    end

    def self.instance_config_schema_location
      @intance_config_schema_location
    end

    class InvalidValidatorError < StandardError
    end

    class Instance < Base
      @@INSTANCE_CONFIG_FILE = "instance-config.xml"
      @@PROVIDED_PARAMS_FILE = "provided-parameters.xml"
      @@IP_FILE = "ip"
      @@EMPTY_DOCUMENT = Nokogiri::XML("")
      @@METADATA_FILE = "meta.yaml"

      # Nokogiri XML validator
      @@validator = nil


      def self.exists?(uuid, service=nil)
        File.exist?(storage_path uuid)
      end

      def self.storage_path(uuid=nil)
        path = uuid ? File.join("instances", uuid) : "instances"
        super path
      end

      def self.find(uuid)
        Instance.new(uuid) if exists?(uuid)
      end

      def self.delete!(uuid)
        FileUtils.rm_rf(storage_path uuid)
      end

      def self.get_validator
        validator_schema = ConfigServer::Model.instance_config_schema_location
        begin
          @@validator ||= open(validator_schema) do |v|
            Nokogiri::XML::RelaxNG(v)
          end
        rescue SocketError => se
          raise InvalidValidatorError,
            "Could not load validator from address #{validator_schema}"
        rescue SystemCallError => sce
          raise InvalidValidatorError,
            "Could not load validator from file #{validator_schema}"
        end
        @@validator
      end

      def self.validate(uuid, xml)
        # make sure the xml is wrapped in Nokogiri
        if xml.instance_of?(String) or xml.kind_of?(IO)
          xml = Nokogiri::XML(xml)
        end
        errors = get_validator.validate(xml)
        if errors.size > 0
          raise InvalidInstanceConfigError.new(errors),
                "The provided instance config for #{uuid} is not a valid " +
                "instance-config document."
        end
        xml
      end

      @uuid = ""
      @secret = nil
      @ip = ""

      attr_reader :instance_config, :ip, :secret, :uuid
      attr_reader :services, :instance_dir
      attr_reader :first_contacted, :last_contacted
      attr_reader :status, :registered_timestamp

      def initialize(uuid, configs=nil)
        super()
        Instance.ensure_storage_path

        @uuid = uuid
        @instance_dir = Instance.storage_path uuid
        @first_contacted = @last_contacted = nil
        @status = @registered_timestamp = nil
        ensure_instance_dir

        if configs.nil?
          load_configs
        else
          replace_instance_config(configs)
        end
        self
      end

      def deployable
        @deployable ||= Deployable.new(deployable_id)
      end

      def assembly_name
        @assembly_name ||=
          (config % 'instance-config')['name'] if not config.nil?
      end

      def service_names
        @service_names ||=
          (@instance_config / '//service').map do |svc|
            svc["name"]
          end
      end

      def ip=(ip)
        replace_ip(ip)
      end

      def service_return_code_values=(params={})
        params.each do |name,val|
          services[name].return_code = val
          services[name].config_ended = DateTime.now
          services[name].store
        end
      end

      def provided_parameters_values=(params={})
        logger.debug("provided params: #{params.inspect}")
        if not (params.nil? or params.empty?)
          params.each do |k,v|
            param = pp % "//provided-parameter[@name='#{k}']"
            param.inner_html = "<value><![CDATA[#{v}]]></value>" if not param.nil?
          end
          File.open(get_path(@@PROVIDED_PARAMS_FILE), 'w') do |f|
            @provided_parameters.write_xml_to(f)
          end
        end
      end

      def provided_parameters(opts={})
        opts[:only_empty] ||= (not opts.has_key? :name)

        params_xml = case
          when opts[:only_empty]
            pp / "//provided-parameter[not(value)]"
          when opts[:name]
            pp / "//provided-parameter[@name='#{opts[:name]}']"
        end

        if opts[:include_values]
          #FIXME: only handles scalar values
          params_xml.map do |p|
            {p['name'] => ((p%'value').nil? ? nil : (p%'value').content)}
          end.inject(:merge) || {}
        else
          params_xml.map do |p|
            p['name']
          end
        end
      end

      def has_unresolved_parameters?
        services.any? {|name, svc| svc.has_unresolved_parameters?}
      end

      def file
        path = get_path("#{@uuid}.tgz")
        return (File.exists?(path)) ? path : nil
      end

      def file=(file)
        if file.nil?
          return nil
        else
          path = get_path("#{@uuid}.tgz")
          File.open(path, "wb") do |f|
            f.write(file[:tempfile].read)
          end
          return path
        end
      end

      def completed_timestamp
        times = services.map {|name,s| s.config_ended}
        times.max if times.compact == times
      end

      def contacted= timestamp
        if not first_contacted
          @first_contacted = timestamp
        end
        @last_contacted = timestamp
        store_metadata
      end

      def status
        states = services.map {|name,svc| svc.status }

        # if all the services reported a status
        # find the "worst" status (error > incomplete > success)
        # otherwise, at least one service couldn't report status = "incomplete"
        # error > incomplete > success
        # which nicely maps to alphabetical order
        states.min
      end

      private
      alias config instance_config

      def provided_parameters_raw
        @provided_parameters || @@EMPTY_DOCUMENT
      end
      alias pp provided_parameters_raw

      def ensure_instance_dir
        FileUtils.mkdir_p(@instance_dir, :mode => 0700) if not File.directory?(@instance_dir)
      end

      def load_configs
        @instance_config = get_xml(get_path(@@INSTANCE_CONFIG_FILE))
        @provided_parameters = get_xml(get_path(@@PROVIDED_PARAMS_FILE))
        @ip = get_ip
        load_services
        load_metadata
        deployable
      end

      def load_services
        @services ||= service_names.map do |svc_name|
          {svc_name => Service.load(self, svc_name)}
        end.reduce(:merge) || {}
      end

      def load_metadata
        metadata = YAML.load_file(get_path(@@METADATA_FILE))
        @first_contacted = metadata["first_contacted"]
        @last_contacted = metadata["last_contacted"]
        @registered_timestamp = metadata["registered"]
      end

      def store_metadata
        metadata = {"first_contacted" => @first_contacted,
            "last_contacted" => @last_contacted,
            "registered" => @registered_timestamp}
        File.open(get_path(@@METADATA_FILE), "w") do |f|
          YAML.dump(metadata, f)
        end
      end

      def get_path(filename)
        File.join(@instance_dir, filename)
      end

      def get_xml(filename)
        File.open(filename) do |f|
          Nokogiri::XML(f)
        end if File.exists?(filename)
      end

      def deployable_id
        (config % '//deployable')['id'] if not config.nil?
      end

      def replace_instance_config(xml)
        xml = Instance.validate(@uuid, xml)
        file = get_path(@@INSTANCE_CONFIG_FILE)
        File.open(file, "w") do |f|
          xml.write_xml_to(f)
        end
        @instance_config = xml
        @registered_timestamp = File.new(@instance_dir).ctime

        replace_provided_parameters
        replace_services
        store_metadata

        replace_tarball

        @secret = get_secret

        deployable
        @deployable.add_instance(@uuid)

        @instance_config
      end

      def get_ip
        filename = get_path(@@IP_FILE)
        File.open(filename) do |f|
          f.read
        end if File.exists?(filename)
      end

      def get_secret
        config.root['secret']
      end

      def replace_ip(ip)
        file = get_path(@@IP_FILE)
        File.open(file, 'w') {|f| f.write(ip) }
      end

      def replace_provided_parameters
        provided_params = config / '//provided-parameter'
        services = config / '//service'
        xml = ""
        if not provided_params.empty?
          xml = "<provided-parameters>\n"
          provided_params.each do |p|
            xml += "  <provided-parameter name='#{p['name']}'/>\n"
          end
          services.each do |s|
            xml += "  <service-parameter name='#{s['name']}'/>\n"
          end
          xml += "</provided-parameters>\n"
        end
        # Always create the provided_params file, even
        # if it's empty...saves a little trouble later
        # on with some validation
        file = get_path(@@PROVIDED_PARAMS_FILE)
        File.open(file, 'w') do |f|
          f.write(xml)
        end
        @provided_parameters = Nokogiri::XML(xml)
      end

      def replace_services
        @services = {}
        (config / '//services/service').each do |svc|
          params = {}
          static_params = svc / '//parameter/value/..'
          reference_params = svc / '//parameter/reference[@provided-parameter]/..'
          service_ref_params = svc / '//parameter/reference[@service-parameter]/..'
          static_params.each do |param|
            params[param["name"]] =
              {"type" => "static", "value" => (param % 'value').content}
          end
          reference_params.each do |param|
            assembly = (param % 'reference')['assembly']
            ref_param = (param % 'reference')['provided-parameter']
            params[param["name"]] =
              {"type" => "parameter-reference", "assembly" => assembly, "parameter" => ref_param}
          end
          service_ref_params.each do |param|
            assembly = (param % 'reference')['assembly']
            service_param = (param % 'reference')['service-parameter']
            params[param["name"]] =
              {"type" => "service-reference", "assembly" => assembly, "service" => service_param}
          end
          service = Service.create(self, svc["name"], params)
          @services[service.name] = service
        end
      end

      def replace_tarball
        # mk a tmpdir
        Dir.mktmpdir do |dir|
          # grab all the executable files and conf files
          get_configuration_scripts(dir, :type => :executable)
          get_configuration_scripts(dir, :type => :file)

          # tar the contents of the tmpdir
          Dir.pushd(dir) do
            tar = File.open(get_path("#{@uuid}.tgz"), 'wb') do |f|
              tgz = Zlib::GzipWriter.new(f)
              Minitar.pack('.', tgz)
            end
          end
        # auto-unlinks the tmpdir
        end
      end

      def get_configuration_scripts(dir, opts={})
        opts[:type] ||= :executable
        config_type = opts[:type]
        (config / config_type.to_s).each do |node|
          config_dir = dir
          parent = (:file == config_type) ? node.parent.parent : node.parent
          if "service" == parent.name
            svc_name = parent['name']
            config_dir = "#{dir}/#{svc_name}"
            Dir.mkdir config_dir if not File.exists? config_dir
          end
          # if file is URL, download file
          # else read file from cdata contents
          begin
            file_data = get_configuration_file(node)
            write_configuration_file(file_data, config_dir, opts[:type])
          rescue => e
            puts "ERROR: could not get configuration file contents"
            puts e
          end

        end
      end

      def get_configuration_file(node)
        file_data = {}
        if not node['url']
          file_content_node = node.first_element_child
          if file_content_node.nil?
            raise "No 'contents' element found for configuration file without url: #{node.name}"
          end
          file_data[:name] = file_content_node[:filename]
          file_data[:body] = file_content_node.content
        else
          file_data = download_file(node['url'])
          if file_data[:code] != "200"
            raise "Could not download file #{node['url']}.  Http Response code: #{file_data[:code]}"
          end
        end
        file_data
      end

      def write_configuration_file(file_data, config_dir, file_type=:executable)
        filename = file_data[:name]
        if file_type == :executable
          open("#{config_dir}/#{filename}", "wb", 0755) do |file|
            file << file_data[:body]
          end
          open("#{config_dir}/start", "wb", 0755) do |file|
            file << file_data[:body]
          end
        else
          open("#{config_dir}/#{filename}", "wb") do |file|
            file << file_data[:body]
          end
        end
      end

      def download_file(url)
        result = {}
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.port == 443
        request = Net::HTTP::Get.new(uri.path)
        response = http.start {|h| h.request(request) }
        result[:code] = response.code
        if "200" == response.code.to_s
          result[:name] = uri.path.split('/').last
          result[:body] = response.body
        end
        result
      end
    end
  end
end
