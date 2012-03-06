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
    class Service < Base
      def self.storage_path
        super @name
      end

      def self.find(name)
        service = Service.new(name)
        service.load
      end

      def self.create(name)
        service = Service.new(name)
        service.store
      end

      def self.find_or_create(name)
        service = find(name) 
        service ? service : create(name)
      end

      attr_reader :name
      attr_accessor :return_code
      def initialize(name)
        super()
        @name = name
        @return_code = nil
        @params = {}
        @meta_file = path 'meta.yaml'
      end

      def ensure_service_dir
        FileUtils.mkdir_p(path, :mode => 0700) if not File.directory?(path)
      end

      def store()
        Service.ensure_storage_path
        ensure_service_dir
        File.open( @meta_file, 'w' ) do |out|
          YAML.dump({'return_code' => @return_code}, out)
        end
        self
      end

      def load
        if exists?
          meta = YAML.load_file( @meta_file ) 
          @return_code = meta['return_code']
          self
        end
      end

      private
      def path(filename=nil)
        p = File.join(Service.storage_path, @name)
        filename ? File.join(p, filename) : p
      end

      def exists?
        File.exists?(path)
      end
    end
  end
end
