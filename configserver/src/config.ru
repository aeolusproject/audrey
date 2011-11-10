root_dir = File.dirname(__FILE__)
version = ENV['AEOLUS_CONFSERVER_VERSION'] || '@VERSION@'
storage_dir = ENV['STORAGE_DIR'] || '/tmp/audrey'
instance_config_rng = ENV['INSTANCE_CONFIG_RNG'] ||
    '/var/lib/aeolus-configserver/schema/instance-config.rng'

env = ENV['RACK_ENV'].to_sym
proxy_type=ENV['PROXY_TYPE']
# when apache is handling auth
proxy_auth_file = ENV['PROXY_AUTH_FILE']

require 'configserver'
set :app_log,             ENV['APPLICATION_LOG']
set :environment,         env
set :storage_dir,         storage_dir
set :instance_config_rng, instance_config_rng
set :root,                root_dir
set :version,             version
set :proxy_type,          proxy_type
set :proxy_auth_file,     proxy_auth_file
ConfigServer::Model.storage_dir = settings.storage_dir
disable :run

require 'logger'
$LOGGER = Logger.new(ENV['APPLICATION_LOG'])
if env == :production
  $LOGGER.level = Logger::INFO
  set :oauth_ignore_post_body, true
else
  $LOGGER.level = Logger::DEBUG
  require 'ruby-debug'
  set :oauth_ignore_post_body, false
end

# This is an awful hack that needs to go away very soon!
# In order to make this go away, Conductor needs to use
# the oauth client to post instance config XML instead of
# using RestClient
if env == :production
  set :oauth_ignore_post_body, true
else
  set :oauth_ignore_post_body, false
end

run Sinatra::Application
