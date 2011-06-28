module ConfigServer
  require 'logger'
  def logger
    @logger ||= Logger.new(settings.log_dir || STDOUT)
  end
end

module ApplicationHelper
  def configs
    ConfigServer::Model.storage_dir = settings.storage_dir
    ConfigServer::Model.instance_config_schema_location =
      settings.instance_config_rng

    @configs ||= ConfigServer::InstanceConfigs.new(settings)
  end

  #def deployables
    #ConfigServer::Deployables.new()
  #end
end
