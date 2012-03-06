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
require 'oauth'
require 'oauth/request_proxy/rack_request'
require 'lib/model/consumer'

module ApplicationHelper
  def logger
    $LOGGER
  end

  def configs
    ConfigServer::Model.instance_config_schema_location =
      settings.instance_config_rng

    @configs ||= ConfigServer::InstanceConfigs.new(settings)
  end

  def app_version
    settings.version
  end

  def api_version
    (1..2)
  end

  def api_version_valid?(version)
    api_version.include? version.to_i
  end

  def api_version_negotiate(agent_versions)
    if agent_versions
      # start with a 0, we'll return this if we don't find
      # a compatible version so the client know's we can't communicate
      version = 0
      agent_versions = agent_versions.split('-')
      agent_versions = agent_versions.map { |x| x.to_i }
      agent_versions.sort.reverse.each do |v|
        if api_version.include?(v)
          return v
        end
      end
    else
      # if an api version is not provided then
      # return the most current api version
      version = api_version.max
    end
    version
  end

  def authenticate!
    if not authenticated? and not legacy_authenticated?
      logger.debug("  **AUTHENTICATING** NOT AUTHENTICATED! (returning 401)")
      throw :halt, [401, "Not Authorized\n"]
    end
  end

  def authenticated?
    authd?
  end

  # Attempts to authenticate the request by not including the request body
  # parameters ("data" or "audrey_data") in the oauth signature validation.
  # Some older OAuth libraries don't include the request parameters in the OAuth
  # Signature value for HTTP PUT requests.
  def legacy_authenticated?
    authd?(true)
  end

  def authd?(ignore_request_body=false)
    unsigned_parameters = ignore_request_body ? ["data", "audrey_data"] : []
    OAuth::Signature.verify(request, :unsigned_parameters => unsigned_parameters) do |request_proxy|
      logger.debug("**AUTHENTICATING** key = #{request_proxy.consumer_key}")
      consumer = ConfigServer::Model::Consumer.find(request_proxy.consumer_key)
      if not consumer.nil?
        [nil, consumer.secret]
      else
        logger.debug("  **AUTHENTICATING** No consumer secret found")
        [nil, ""]
      end
    end
  end
end
