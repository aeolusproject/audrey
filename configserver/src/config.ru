require 'configserver'

root_dir = File.dirname(__FILE__)
version = ENV['AEOLUS_CONFSERVER_VERSION'] || '@VERSION@'
storage_dir = ENV['STORAGE_DIR'] || '/tmp/audrey'
instance_config_rng = ENV['INSTANCE_CONFIG_RNG'] ||
    '/var/lib/aeolus-configserver/schema/instance-config.rng'

proxy_type=ENV['PROXY_TYPE']
# when apache is handling auth
proxy_auth_file = ENV['PROXY_AUTH_FILE']

set :environment,         ENV['RACK_ENV'].to_sym
set :logging,             true
set :storage_dir,         storage_dir
set :instance_config_rng, instance_config_rng
set :root,                root_dir
set :version,             version
set :proxy_type,          proxy_type
set :proxy_auth_file,     proxy_auth_file
set :app_file,            File.join(root_dir, 'hello.rb')
disable :run

run Sinatra::Application
