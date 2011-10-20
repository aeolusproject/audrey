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

      def initialize(errors=nil, cause=nil)
        @errors = errors if not errors.nil?
        @cause = cause if not cause.nil?
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
      @@REQUIRED_PARAMS_FILE = "required-parameters.xml"
      @@IP_FILE = "ip"
      @@EMPTY_DOCUMENT = Nokogiri::XML("")

      # Nokogiri XML validator
      @@validator = nil

      attr_reader :instance_config, :ip, :secret, :uuid

      def self.exists?(uuid)
        File.exist?(File.join(storage_path, uuid))
      end

      def self.storage_path
        super "instances"
      end

      def self.find(uuid)
        Instance.new(uuid) if exists?(uuid)
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
        errors = []
        begin
          errors = get_validator.validate(xml)
        rescue Exception => e
          raise InvalidInstanceConfigError.new(), ["The provided instance " +
              "config for #{uuid} caused an error during validation:  ", e]
        end
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
      @instance_dir = ""

      def initialize(uuid, configs=nil)
        super()
        Instance.ensure_storage_path

        @uuid = uuid
        @instance_dir = File.join(Instance.storage_path, uuid)
        ensure_instance_dir

        if configs.nil?
          load_configs
        else
          replace_instance_config(configs)
        end
        self
      end

      def delete!
        FileUtils.rm_rf(@instance_dir)
        @uuid = nil
        @ip = nil
        @instance_dir = nil
        @instance_config = nil
        @provided_parameters = nil
        @required_parameters = nil
        @deployable = nil
        @assembly_name = nil
      end

      def deployable
        @deployable ||= Deployable.new(deployable_id)
      end

      def assembly_name
        @assembly_name ||=
          (config % 'instance-config')['name'] if not config.nil?
      end

      def instance_config=(xml)
        replace_instance_config(xml)
      end

      def ip=(ip)
        replace_ip(ip)
      end

      def provided_parameters_values=(params={})
        puts "provided params: #{params.inspect}"
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
        opts[:only_empty] ||= (not (opts[:only_with_values] || opts[:all]))
        if opts[:raw]
          return provided_parametrs_raw
        end

        xpath = case
          when opts[:only_empty]
            '//provided-parameter[not(value)]'
          when opts[:only_with_values]
            '//provided-parameter/value/..'
          else # opts[:all]
            '//provided-parameter'
        end

        if opts[:include_values]
          #FIXME: only handles scalar values
          (pp / xpath).map do |p|
            {p['name'] => ((p%'value').nil? ? nil : (p%'value').content)}
          end.inject(:merge)
        else
          (pp / xpath).map do |p|
            p['name']
          end
        end
      end

      def required_parameters_values=(params={})
        puts "required params: #{params.inspect}"
        params.each do |k,v|
          param = rp % "//required-parameter[@name='#{k}']"
          puts "param: #{param.to_xml}"
          puts "value: #{v}"
          param.inner_html = "<value><![CDATA[#{v}]]></value>" if not param.nil?
        end if not (params.nil? or params.empty?)
        File.open(get_path(@@REQUIRED_PARAMS_FILE), 'w') do |f|
          rp.write_xml_to(f)
        end
      end

      def required_parameters(opts={})
        if opts[:raw]
          return required_parameters_raw
        end

        xpath = case
          when opts[:only_empty]
            '//required-parameter[not(value)]'
          when opts[:only_with_values]
            '//required-parameter/value/..'
          else # opts[:all]
            '//required-parameter'
        end

        params = (rp / xpath).map do |p|
          {:name      => p['name'],
           :assembly  => p['assembly'],
           :parameter => p['parameter']} +
          if opts[:include_values]
            #FIXME: only handles scalar values
            v = p % 'value'
            {:value   => (v.content if not v.nil?)}
          else
            {}
          end
        end
      end

      def services
        services = ActiveSupport::OrderedHash.new
        (config / '//service').each do |s|
          name = s["name"]
          params_with_values = (s / './parameters/parameter/value/..') +
            (rp / "//required-parameter[@service='#{name}']/value/..")
          parameters = (params_with_values.map do |p|
            {p["name"] => (p % 'value').content}
          end || []).inject(:merge) || {}
          services[name] = parameters
        end
        services
      end

      def required_parameters_remaining?
        (rp / "//required-parameter[not(value)]").size > 0
      end

      def has_file?
        File.exists?(get_file)
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

      private
      alias config instance_config

      def required_parameters_raw
        @required_parameters || @@EMPTY_DOCUMENT
      end
      alias rp required_parameters_raw

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
        @required_parameters = get_xml(get_path(@@REQUIRED_PARAMS_FILE))
        @ip = get_ip
        deployable
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

        replace_provided_parameters
        replace_required_parameters

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
        xml = ""
        if not provided_params.empty?
          xml = "<provided-parameters>\n"
          provided_params.each do |p|
            xml += "  <provided-parameter name='#{p['name']}'/>\n"
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

      def replace_required_parameters
        file = get_path(@@REQUIRED_PARAMS_FILE)
        # grab all the services with reference parameters
        services = config / '//service/parameters/parameter/reference/../../..'
        if not services.empty?
          xml = "<required-parameters>\n"
          services.each do |s|
            xml += "  <required-parameter service='#{s['name']}'"
            (services / './parameters/parameter/reference/..').each do |p|
              xml += " name='#{p['name']}'"
              ref = p % 'reference'
              xml += " assembly='#{ref['assembly']}'"
              xml += " parameter='#{ref['provided-parameter']}'/>\n"
            end
          end
          xml += "</required-parameters>\n"
          puts "reqparams xml: #{xml}"

          File.open(file, 'w') do |f|
            f.write(xml)
          end
          @required_parameters = Nokogiri::XML(xml)
        else
          File.delete(file) if File.exists?(file)
          @required_parameters = nil
        end
      end

      def replace_tarball
        # mk a tmpdir
        Dir.mktmpdir do |dir|
          # download all the executable files
          download_files(dir, :type => :executable)
          # download all the general files
          download_files(dir, :type => :file)

          # tar the contents of the tmpdir
          Dir.pushd(dir) do
            tar = File.open(get_path("#{@uuid}.tgz"), 'wb') do |f|
              tgz = Zlib::GzipWriter.new(f)
              Minitar.pack('.', tgz)
            end
          end
        # unlink the tmpdir
        end
      end

      def download_files(dir, opts={})
        type = opts[:type] || :executable
        if not [:executable, :file].include? type
          raise RuntimeError, "unknown download file type #{type.to_s}"
        end
        (config / type.to_s).each do |node|
          download_dir = dir
          parent = (:file == type) ? node.parent.parent : node.parent
          if "service" == parent.name
            svc_name = parent['name']
            download_dir = "#{dir}/#{svc_name}"
            Dir.mkdir download_dir if not File.exists? download_dir
          end
          download = download_file(node['url'])
          if "200" == download[:code]
            puts "Downloaded file #{node['url']}: #{download[:body].size}b"
            filename = (:file == type) ? download[:name] : "start"
            if type == :executable
              open("#{download_dir}/#{filename}", 'wb', 0777) do |file|
                file << download[:body]
              end
            else
              open("#{download_dir}/#{filename}", 'wb') do |file|
                file << download[:body]
              end
            end
          else
            puts "ERROR(#{download[:code]}): could not download file #{node['url']}"
            # TODO: log that the config server could not download the file...
            # bundle up errors to return...
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

      def pending_required_params?(service=nil)
        xpath = (service.nil?) ?
          '//required-parameter[not(value)]' :
          "//required-parameter[@service='#{service}'][not(value)]"
        not (rp.nil? or (rp / xpath).empty?)
      end
    end
  end
end
