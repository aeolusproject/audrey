module ConfigServer
  require 'logger'
  def logger
    @logger ||= Logger.new(settings.log_dir || STDOUT)
  end
end

module ApplicationHelper
  def configs
    puts "ApplicationHelper::configs"
    @configs ||= ConfigServer::InstanceConfigs.new(
        :storage_dir => settings.storage_dir,
        :instance_config_rng => settings.instance_config_rng)
  end

  #def deployables
    #ConfigServer::Deployables.new()
  #end
end
