env = ENV['RACK_ENV'].to_sym

require 'common_config'

set :environment,         env

require 'logger'
# create the log file with the correct permissions
file = File.open(ENV['APPLICATION_LOG'], File::APPEND | File::CREAT | File::WRONLY, 0600)
file.close
# open the file with the logger for better flushing
$LOGGER = Logger.new(file.path)
if env == :production
  $LOGGER.level = Logger::INFO
else
  $LOGGER.level = Logger::DEBUG
  require 'ruby-debug'
end

run Sinatra::Application
