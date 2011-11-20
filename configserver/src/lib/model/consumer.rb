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
    class Consumer < Base
      def self.storage_path
        super "oauth"
      end

      def self.find(key)
        consumer = Consumer.new(key)
        consumer.load
      end

      def self.create(key, secret)
        consumer = Consumer.new(key)
        consumer.store(secret)
      end

      attr_reader :key, :secret
      def initialize(key)
        super()
        @key = key
        @secret = nil
      end

      def store(secret)
        File.open(path, "w", 0600) {|f| f.write(secret)}
        self
      end

      def load
        if exists?
          File.open(path, "r") {|f| @secret = f.read.chomp}
          self
        end
      end

      private
      def path
        File.join(Consumer.storage_path, key)
      end

      def exists?
        File.exists?(path)
      end
    end
  end
end
