# EventHub module
module EventHub
  def self.logger
    unless defined?(@logger)
      @logger = ::EventHub::Components::MultiLogger.new
      @logger.add_device(Logger.new($stdout))

      unless Configuration.console_log_only
        @logger.add_device(
          EventHub::Components::Logger.logstash(Configuration.name,
            Configuration.environment)
        )
      end
    end
    @logger
  end
end
