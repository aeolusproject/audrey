require 'cgi'
require 'sinatra'
require 'rubygems'

require 'lib/config_handler' # I don't like this name
require 'lib/application_helper'
require 'logger'

helpers ApplicationHelper

configure :development do
  enable :logging, :dump_errors
  set :raise_errors, true
end

configure :production do
  enable :logging
end

error 400 do
  #FIXME: point the requestor to the relaxNG document used to parse the XML
  # document.
  #FIXME: show the requestor the set of errors that occured
  "Could not parse the given XML document.\n"
end


before '/configs/*' do
  authenticate!
end
before '/params/*' do
  authenticate!
end
before '/files/*' do
  authenticate!
end
before '/auth*' do
  authenticate!
end

get '/auth' do
  logger.debug("Client is testing auth credentials")
  "Authentication test successful"
end

## GET /version
# Retrieve the Application and API version for this config server
get '/version', :provides => ['text', 'xml'] do
  logger.debug("Getting the version as text or XML")
  "<config-server>\n" +
  "  <application-version>#{app_version}</application-version>\n" +
  "  <api-version>#{api_version}</api-version>\n" +
  "</config-server>"
end

get '/version' do
  logger.debug("Getting the version as HTML")
  "<config-server>\n" +
  "<config-server>\n" +
  "Application Version: #{app_version}<br/>\n" +
  "API Version: #{api_version}<br/>\n"
end


## GET /ip/
# Retrieve the IP address for an instance that has reported its IP
get '/ip/:version/:uuid', :provides => ['text', 'html'] do
  configs.exists?(params[:uuid]) ?
    configs.get_ip(params[:uuid]) :
    not_found
end

## GET /configs/
# Retrieve the configuration information for an instance
get '/configs/:version/:uuid', :provides => 'text' do
  if not api_version_valid?(request, params[:version]) or
      not configs.exists?(params[:uuid])
    not_found
  else
    confs, more_configs = configs.get_configs(params[:uuid], :as => :text)
    status = more_configs ? 202 : 200
    [status, confs]
  end
end

get '/configs/:version/:uuid', :provides => 'xml' do
  if not api_version_valid?(request, params[:version]) or
      not configs.exists?(params[:uuid])
    not_found
  else
    confs, more_configs = configs.get_configs(params[:uuid], :as => :xml)
    status = more_configs ? 202 : 200
    [status, confs]
  end
end

get '/configs/:version/:uuid' do
  if not api_version_valid?(request, params[:version]) or
      not configs.exists?(params[:uuid])
    not_found
  else
    confs, more_configs = configs.get_configs(params[:uuid], :as => :xml)
    status = more_configs ? 202 : 200
    [status, confs]
  end
end

## POST /configs/
# Create (or completely replace) the configuration data for an instance
post '/configs/:version/:uuid' do
  # For now, we're not going to validate the version here
  # The current XML validation should be enough for the moment
  # Really handling version checking here will require a patch to conductor
  #if not api_version_valid?(request, params[:version])
    #not_found
  #else
    logger.debug("Post data: #{params[:data]}")
    begin
      configs.create(params[:uuid], params[:data])
    rescue ConfigServer::InvalidInstanceConfigError
      400
    end
  #end
end

## DELETE /configs/
# Permanently delete the configuration data for an instance
delete '/configs/:version/:uuid' do
  configs.delete(params[:uuid])
end

## GET /files/
# Retrieve the configuration files for an instance
get '/files/:version/:uuid' do
  if not api_version_valid?(request, params[:version])
    not_found
  else
    file = configs.get_file(params[:uuid])
    if file.nil?
      not_found
    else
      send_file file,
        :filename => "#{params[:uuid]}.tgz",
        :type => "application/x-tar"
    end
  end
end

## PUT /files/
# Add configuration files for an instance
put '/files/:version/:uuid' do
  if not api_version_valid?(request, params[:version]) or
      not configs.exists?(params[:uuid])
    not_found
  else
    uuid = params[:uuid]
    file = params[:file]
    configs.save_file(uuid, file)
  end
end

## GET /params/
# Retrieve the list of "return" parameters names for an instance
get '/params/:version/:uuid', :provides => 'text' do
  if not api_version_valid?(request, params[:version]) or
      not configs.exists?(params[:uuid])
    not_found
  else
    provides = configs.get_provides(params[:uuid], :as => :text)
    logger.debug("GET params: #{provides}")
    provides
  end
end

get '/params/:version/:uuid', :provides => 'xml' do
  if not api_version_valid?(request, params[:version]) or
      not configs.exists?(params[:uuid])
    not_found
  else
    provides = configs.get_provides(params[:uuid], :as => :xml)
    logger.debug("GET params: #{provides}")
    provides
  end
end

## PUT /params/
# Set the live of "return" parameter values for an instance
put '/params/:version/:uuid' do
  if not api_version_valid?(request, params[:version]) or
      not configs.exists?(params[:uuid])
    not_found
  else
    logger.debug("PUT params: #{params[:audrey_data]}")
    configs.update(params[:uuid], params[:audrey_data], request.ip)
  end
end
