require 'configserver'

root_dir = File.dirname(__FILE__)
storage_dir = ENV['STORAGE_DIR'] || '/tmp/audrey'
instance_config_rng = ENV['INSTANCE_CONFIG_RNG'] ||
    '/var/lib/aeolus-configserver/schema/instance-config.rng'

set :environment,         ENV['RACK_ENV'].to_sym
set :storage_dir,         storage_dir
set :instance_config_rng, instance_config_rng
set :root,                root_dir
set :app_file,            File.join(root_dir, 'hello.rb')
disable :run

run Sinatra::Application
