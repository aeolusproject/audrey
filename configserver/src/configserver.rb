require 'sinatra'
require 'rubygems'
require 'fileutils'

STORAGE_DIR='/tmp/audrey'

before do
  ensure_home_dir
end

## HTTP Interface

## GET request
# Matches GET /configs/123
# Attempts to retrieve the configuration data associated with :uuid
get '/configs/:uuid', :provides => 'yaml' do
  dir_exists?(params[:uuid]) ? retrieve(params[:uuid]) : not_found
end

## POST request
# Matches POST /configs
# Extracts the uuid and associated configuration data from the POST body and
# creates (or updates) the configuration data for the uuid.
# In the case of an update, the data is fully replaced.
post '/configs' do
  update(params[:uuid], params[:data])
end

## PUT request
# Matches PUT /configs
# Extracts the uuid and associated configuration data from the POST body and
# creates (or updates) the configuration data for the uuid.
# In the case of an update, the data is fully replaced.
put '/configs' do
  update(params[:uuid], params[:data])
end

## DELETE request
# Matches DELETE /configs/123
# Deletes the configuration data associated with :uuid
delete '/configs/:uuid' do
  delete(params[:uuid])
end

## Helpers

def dir_exists?(uuid)
  File.directory?(getdir(uuid))
end

def retrieve(uuid)
  dir = getdir(uuid)
  return File.directory?(dir) ? IO.read(dir + '/data.yaml') : ""
end

def update(uuid, data)
  dir = getdir(uuid)
  if File.directory?(dir)
    # for now this is an outright replacement
    # probably can get more sophisticated if needed
    File.open(dir + '/data.yaml', 'w') do |f|
      f.puts data
    end
  else
    create(uuid, data)
  end
end

def create(uuid, data)
  dir = getdir(uuid)
  Dir.mkdir(dir) unless File.directory?(dir)
  File.open(dir + '/data.yaml', 'w') do |f|
    f.puts data
  end
end

def delete(uuid)
  FileUtils.rm_rf(getdir(uuid))
end

def getdir(uuid)
  return STORAGE_DIR + '/' + uuid
end

def ensure_home_dir
  Dir.mkdir(STORAGE_DIR) unless File.directory?(STORAGE_DIR)
end
