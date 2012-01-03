env = ENV['RACK_ENV'].to_sym

require 'common_config'

set :environment,         env

require 'logger'
$LOGGER = Logger.new(ENV['APPLICATION_LOG'])
if env == :production
  $LOGGER.level = Logger::INFO
else
  $LOGGER.level = Logger::DEBUG
  require 'ruby-debug'
end

run Sinatra::Application
