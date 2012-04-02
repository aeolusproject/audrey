#
#   Copyright [2011] [Red Hat, Inc.]
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#  limitations under the License.
#
require 'cgi'
require 'rubygems'
require 'sinatra'

require 'lib/config_handler' # I don't like this name
require 'lib/report_server'
require 'lib/application_helper'

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

## GET /version
# Retrieve the Application and API version for this config server
get '/version', :provides => ['text', 'xml'] do
  logger.debug("Getting the version as text or XML")
  "<config-server>\n" +
  "  <application-version>#{app_version}</application-version>\n" +
  "  <api-version>#{api_version_negotiate(params[:api_compat])}</api-version>\n" +
  "</config-server>"
end

get '/version' do
  logger.debug("Getting the version as HTML")
  "<html><body>\n" +
  "<li>Application Version: #{app_version}</li>\n" +
  "<li>API Version: #{api_version_negotiate(params[:api_compat])}<li/>\n" +
  "</body></html>"
end

# OAuth protected URLs
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
before '/*/:version/*' do
  # Validate the api version
  if not api_version_valid?(params[:version])
    not_found
  end
end

# Test OAuth
get '/auth' do
  logger.debug("Client is testing auth credentials")
  "Authentication test successful"
end

#
# API Methods
#

## GET /ip/
# Retrieve the IP address for an instance that has reported its IP
get '/ip/:version/:uuid', :provides => ['text', 'html'] do
  configs.exists?(params[:uuid]) ?
    configs.get_ip(params[:uuid]) :
    not_found
end

## GET /configs/
# Retrieve the configuration information for an instance
get '/configs/:version/:uuid/?:service?' do
  if not configs.exists?(params[:uuid])
    not_found
  else
    confs, more_configs = configs.get_configs(params[:uuid], params[:service])
    status = more_configs ? 202 : 200
    [status, confs]
  end
end

## POST /configs/
# Create (or completely replace) the configuration data for an instance
post '/configs/:version/:uuid' do
  logger.debug("Post data: #{params[:data]}")
  begin
    configs.create(params[:uuid], params[:data])
  rescue ConfigServer::Model::InvalidInstanceConfigError
    400
  end
end

## DELETE /deployment/
# Permanently delete the configuration data for an entire deployment
#  - delete all instance configurations under that deployment
delete '/deployment/:version/:uuid' do
  if not configs.deployment_exists?(params[:uuid])
    not_found
  else
    configs.delete_deployment(params[:uuid])
  end
end

## GET /files/
# Retrieve the configuration files for an instance
get '/files/:version/:uuid' do
  file = configs.get_file(params[:uuid])
  if file.nil?
    not_found
  else
    send_file file,
      :filename => "#{params[:uuid]}.tgz",
      :type => "application/x-tar"
  end
end

## PUT /files/
# Add configuration files for an instance
put '/files/:version/:uuid' do
  if not configs.exists?(params[:uuid])
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
  if not configs.exists?(params[:uuid])
    not_found
  else
    provides = configs.get_provides(params[:uuid], :apiv => params[:version])
  end
end

## PUT /params/
# Set the live of "return" parameter values for an instance
put '/params/:version/:uuid' do
  if not configs.exists?(params[:uuid])
    not_found
  else
    logger.debug("PUT params: #{params[:audrey_data]}")
    provides = configs.update(params[:uuid], params[:audrey_data], request.ip)
    status = ("||" == provides) ? 200 : 202
    [status, provides]
  end
end

########################
# Reporting API
#

get '/reports/:version/deployment/:uuid' do
  if not configs.deployment_exists?(params[:uuid])
    not_found
  else
    reports.deployment_report(params[:uuid])
  end
end

get '/reports/:version/instance/:uuid' do
  if not configs.exists?(params[:uuid])
    not_found
  else
    reports.instance_report(params[:uuid])
  end
end
