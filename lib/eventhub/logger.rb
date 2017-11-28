# Eventhub module
module Eventhub

  def self.logger
    unless @logger
      @logger = ::EventHub::Components::MultiLogger.new
      @logger.add_device(Logger.new(STDOUT))
      @logger.add_device(EventHub::Components::Logger.logstash(Configuration.name, Configuration.environment))
    end
    @logger
  end

end
