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
module ConfigServer
  module Model
    class Service
      def self.create(instance, name, params=nil)
        service = Service.new(instance, name)
        service.params = params
        service.store
      end

      def self.load(instance, name)
        Service.new(instance, name)
      end

      attr_reader :name, :instance
      attr_accessor :return_code, :params
      attr_accessor :config_started, :config_ended
      def initialize(instance, name)
        @name = name
        @instance = instance
        @return_code = nil
        @config_started = nil
        @config_ended = nil
        @params = {}
        @meta_file = 'meta.yaml'
        @params_file = 'params.yaml'
        if exists?
          load_service
        end
      end

      def ensure_service_dir
        FileUtils.mkdir_p(path, :mode => 0700) if not File.directory?(path)
      end

      def store()
        ensure_service_dir
        File.open(path(@meta_file), 'w') do |out|
          YAML.dump(metadata, out)
        end
        if not @params.empty?
          File.open(path(@params_file), 'w') do |out|
            YAML.dump(@params, out)
          end
        end
        self
      end

      def load_service
        if exists? @meta_file
          meta = YAML.load_file(path(@meta_file))
          @return_code = meta['return_code']
          @config_started = meta['config_started']
          @config_ended = meta['config_ended']
        end
        if exists? @params_file
          @params = YAML.load_file(path(@params_file))
        end
        self
      end

      def has_unresolved_parameters?
        # use params and not @params in order to get as many
        # reference values resolved as possible
        params.any? {|name, data| data["value"].nil?}
      end

      def unresolved_parameters
        params.reject do |name, data|
          not (data["value"].nil? and
            (["parameter-reference", "service-reference"].include? data["type"])
          )
        end
      end

      def params
        # resolves parameter and service references each time
        # this is on purpose ... want to enable resolved values to change over
        # time
        @params.each do |name, data|
          unless data.keys.include?("value")
            case data["type"]
              when "parameter-reference"
                data["value"] =
                  instance.deployable.resolve_parameter_reference(
                    data["assembly"], data["parameter"])
              when "service-reference"
                data["value"] =
                  instance.deployable.resolve_service_reference(
                    data["assembly"], data["service"])
            end
          end
        end
      end

      def status
        if @return_code
          if @return_code.to_s == "0"
            "success"
          else
            "error"
          end
        else
          "incomplete"
        end
      end

      private
      def path(filename=nil)
        p = File.join(instance.instance_dir, @name)
        filename ? File.join(p, filename) : p
      end

      def exists?(filename=nil)
        File.exists?(path(filename))
      end

      def metadata
        {"return_code" => @return_code,
         "config_started" => @config_started,
         "config_ended" => @config_ended}
      end
    end
  end
end
