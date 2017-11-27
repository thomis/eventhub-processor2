# Eventhub module
module Eventhub

  @name = 'undefined'
  @environment = 'development'

  def self.logger
    unless @logger
      @logger = ::EventHub::Components::MultiLogger.new
      @logger.add_device(Logger.new(STDOUT))
      @logger.add_device(EventHub::Components::Logger.logstash(@name, @environment))
    end
    @logger
  end

  def self.set_logger(name, environment)
    @name = name
    @environment = environment
  end
end
