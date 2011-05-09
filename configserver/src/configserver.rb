require 'cgi'
require 'sinatra'
require 'rubygems'

configure do
  #set :storage_dir => '/tmp/audrey/'
end

#configure :production do
  #set :storage_dir => '/var/lib/aeolus-configserver/'
#end

require 'lib/config_handler' # I don't like this name
require 'lib/application_helper'

helpers ApplicationHelper

error 400 do
  #FIXME: point the requestor to the relaxNG document used to parse the XML
  # document.
  #FIXME: show the requestor the set of errors that occured
  "Could not parse the given XML document.\n"
end


get '/ip/:version/:uuid', :provides => ['text', 'html'] do
  configs.exists?(params[:uuid]) ?
    configs.get_ip(params[:uuid]) :
    not_found
end

## GET request
# Matches GET /configs/0.0.1/123
# Attempts to retrieve the configuration data (as xml) associated with :uuid
# try:
#     curl -w "HTTP_CODE: %{http_code}\n" -H "Accept: application/xml" \
#     http://localhost:4567/configs/0.0.1/1234
get '/configs/:version/:uuid', :provides => 'xml' do
  configs.exists?(params[:uuid]) ?
    configs.get_configs(params[:uuid], :as => :xml) :
    not_found
end


## GET request
# Matches GET /configs/0.0.1/123
# Attempts to retrieve the configuration data (as text) associated with :uuid
# try:
#     curl -w "HTTP_CODE: %{http_code}\n" -H "Accept: text/plain" \
#     http://localhost:4567/configs/0.0.1/1234
get '/configs/:version/:uuid', :provides => 'text' do
  configs.exists?(params[:uuid]) ?
    configs.get_configs(params[:uuid], :as => :text) :
    not_found
end


## GET request
# Matches GET /params/0.0.1/123
# Attempts to retrieve the "provides" parameters associated with :uuid
# try:
#     curl -w "HTTP_CODE: %{http_code}\n" -H "Accept: application/xml" \
#     http://localhost:4567/params/0.0.1/1234
get '/params/:version/:uuid', :provides => 'xml' do
  configs.exists?(params[:uuid]) ?
    configs.get_provides(params[:uuid], :as => :xml) :
    not_found
end


## GET request
# Matches GET /params/0.0.1/123
# Attempts to retrieve the "provides" parameters associated with :uuid
# try:
#     curl -w "HTTP_CODE: %{http_code}\n" -H "Accept: text/plain" \
#     http://localhost:4567/params/0.0.1/1234
get '/params/:version/:uuid', :provides => 'text' do
  configs.exists?(params[:uuid]) ?
    configs.get_provides(params[:uuid], :as => :text) :
    not_found
end


## POST request
# Matches POST /configs/0.0.1/123
# Creates the configuration data related to uuid.
# If configuration data for uuid already exists, it is completely replaced.  For
# instance, if calls to PUT /params have been called to update the provided
# param data for this uuid, the entire set of updated provided param data is
# deleted (i.e., reset to it's start state of not having any values set for
# provided params).
# try:
#     curl -w "HTTP_CODE: %{http_code}\n" \
#     -d "data=this+is+just+a+test" \
#     http://localhost:4567/configs/0.0.1/123
post '/configs/:version/:uuid' do
  begin
    configs.create(params[:uuid], params[:data])
  rescue ConfigServer::InvalidInstanceConfigError
    400
  end
end

## PUT request
# Matches PUT /params/0.0.1/1234
# Extracts the uuid and associated configuration data from the HEADER data and
# updates the provided parameter data for the given uuid.  Response data
# contains the list of provided params that still need to be provided.
# Supplying a param value for a provided param that already exists for this uuid
# results in replacing that param value with the newly given value.
# If the given uuid doesn't already have configurations on this server, then
# HTTP_CODE 404 is returned.
# try:
#     curl -w "HTTP_CODE: %{http_code}\n" -X PUT \
#     -d "audrey_data=|param1&value1|param2&value2|" \
#     http://localhost:4567/params/0.0.1/1234
put '/params/:version/:uuid' do
  configs.exists?(params[:uuid]) ?
    configs.update(params[:uuid], params[:audrey_data], request.ip) :
    not_found
end

## DELETE request
# Matches DELETE /configs/0.0.1/123
# Deletes the configuration data associated with :uuid
# try:
#     curl -X DELETE http://localhost:4567/configs/1234
delete '/configs/:version/:uuid' do
  configs.delete(params[:uuid])
end
