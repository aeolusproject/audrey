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
