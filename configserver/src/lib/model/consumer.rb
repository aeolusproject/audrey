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
