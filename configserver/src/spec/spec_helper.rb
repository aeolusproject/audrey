require 'test/spec'
require 'rspec'
require 'rack/test'
require 'ruby-debug'
require 'logger'

ENV['INSTANCE_CONFIG_RNG'] = '../schema/instance-config.rng'
require 'common_config'
# HACK, see config.in.ru for details
set :oauth_ignore_post_body, false
set :environment, :test

$LOGGER = Logger.new('DEBUG')

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  #conf.after(:all) do
  #    storage = :storage_dir.to_s
  #    FileUtils.rm_rf(Dir[storage])
  #end
end

def app
  Sinatra::Application
end
