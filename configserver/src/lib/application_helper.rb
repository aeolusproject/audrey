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
    "1"
  end

  def api_version_valid?(request, version)
    root_path = request.path[0, (request.path.index('/', 1) + 1)]
    if ["/params/", "/configs/", "/files/"].include? root_path
      return api_version == version.to_s
    end
    return true
  end

  def authenticate!
    if not authenticated?
      logger.debug("  **AUTHENTICATING** NOT AUTHENTICATED! (returning 401)")
      throw :halt, [401, "Not Authorized\n"]
    end
  end

  def authenticated?
    unsigned_parameters = settings.oauth_ignore_post_body ? ["data", "audrey_data"] : []
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
