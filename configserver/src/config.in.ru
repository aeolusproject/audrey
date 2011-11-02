env = ENV['RACK_ENV'].to_sym

require 'common_config'

set :environment,         env

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
