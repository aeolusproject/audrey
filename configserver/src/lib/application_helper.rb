use Rack::Logger

module ApplicationHelper
  def logger
    request.logger
  end

  def configs
    ConfigServer::Model.storage_dir = settings.storage_dir
    ConfigServer::Model.instance_config_schema_location =
      settings.instance_config_rng

    @configs ||= ConfigServer::InstanceConfigs.new(settings, request.logger)
  end

  def app_version
    settings.version
  end

  def api_version
    "1"
  end

  def api_version_valid?(request, version)
    root_path = request.path[0, (request.path.index('/', 1) + 1)]
    if ["/params/", "/configs/"].include? root_path
      return api_version == version.to_s
    end
    return true
  end
end
