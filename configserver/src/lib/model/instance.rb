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
      @@REQUIRED_PARAMS_FILE = "required-parameters.xml"
      @@IP_FILE = "ip"
      @@EMPTY_DOCUMENT = Nokogiri::XML("")

      # Nokogiri XML validator
      @@validator = nil

      attr_reader :instance_config, :ip, :secret, :uuid

      def self.exists?(uuid)
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
        @instance_dir = Instance.storage_path uuid
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

      def instance_config=(xml)
        replace_instance_config(xml)
      end

      def ip=(ip)
        replace_ip(ip)
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
        logger.debug("required params: #{params.inspect}")
        params.each do |k,v|
          param = rp % "//required-parameter[@name='#{k}']"
          logger.debug("param: #{param.to_xml}")
          logger.debug("value: #{v}")
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
            (services / './parameters/parameter/reference/..').each do |p|
              xml += "  <required-parameter service='#{s['name']}'"
              xml += " name='#{p['name']}'"
              ref = p % 'reference'
              xml += " assembly='#{ref['assembly']}'"
              xml += " parameter='#{ref['provided-parameter']}'/>\n"
            end
          end
          xml += "</required-parameters>\n"
          logger.debug("reqparams xml: #{xml}")

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
        if not [:executable, :file].include? config_type
          raise RuntimeError, "unknown configuration file type #{config_type}"
        end
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
        filename = (:file == file_type) ? file_data[:name] : "start"
        if file_type == :executable
          open("#{config_dir}/#{filename}", "wb", 0777) do |file|
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

      def pending_required_params?(service=nil)
        xpath = (service.nil?) ?
          '//required-parameter[not(value)]' :
          "//required-parameter[@service='#{service}'][not(value)]"
        not (rp.nil? or (rp / xpath).empty?)
      end
    end
  end
end
