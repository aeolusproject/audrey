require 'fileutils'

module ConfigServer
  module Model
    @@storage_dir = ""
    @@instance_config_schema_location = ""

    @@configurable_mapping = {}

    def self.add_configurable_mapping(name, klass)
      @@configurable_mapping[name] = klass
    end

    def self.storage_dir=(dir)
      @@storage_dir = dir
    end

    def self.storage_dir
      @@storage_dir
    end

    def self.update_required_parameters_in_deployable(params={})
    end

    class Base
      def initialize
        Base.ensure_storage_path
      end

      def logger
        $LOGGER
      end

      def self.ensure_storage_path
        path = storage_path
        if not (path.nil? or path.empty? or File.directory?(path))
          FileUtils.mkdir_p(path, :mode => 0700)
        end
      end

      def self.storage_path(path=nil)
        # implement this method to return the storage directory for the model
        # object
        #
        return (path.nil?) ?
          ConfigServer::Model.storage_dir :
          File.join(ConfigServer::Model.storage_dir, path)
      end
    end
  end
end
