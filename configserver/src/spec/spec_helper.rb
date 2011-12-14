require 'test/spec'
require 'rspec'
require 'rack/test'
require 'ruby-debug'
require 'logger'

ENV['INSTANCE_CONFIG_RNG'] = '../schema/instance-config.rng'
require 'common_config'
# HACK, see config.in.ru for details
set :environment, :test

$LOGGER = Logger.new('DEBUG')

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  conf.after(:all) do
    FileUtils.rm_rf(Dir[settings.storage_dir])
  end
end

def app
  Sinatra::Application
end

class FakeHttp
  attr_accessor :use_ssl

  def start
    self
  end
  def code
    "200"
  end
  def body
    'fake download file body'
  end
end
