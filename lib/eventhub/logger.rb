# EventHub module
module EventHub
  # Logger proxy that automatically includes correlation_id in structured log output
  class LoggerProxy
    def initialize(logger)
      @logger = logger
    end

    %i[debug info warn error fatal unknown].each do |level|
      define_method(level) do |message = nil, &block|
        message = block.call if block
        correlation_id = CorrelationId.current
        execution_id = ExecutionId.current
        if correlation_id || execution_id
          log_hash = {message: message}
          log_hash[:correlation_id] = correlation_id if correlation_id
          log_hash[:execution_id] = execution_id if execution_id
          @logger.send(level, log_hash)
        else
          @logger.send(level, message)
        end
      end
    end

    def method_missing(method, *args, &block)
      @logger.send(method, *args, &block)
    end

    def respond_to_missing?(method, include_private = false)
      @logger.respond_to?(method, include_private)
    end
  end

  def self.logger
    unless defined?(@logger)
      base_logger = ::EventHub::Components::MultiLogger.new

      if Configuration.console_log_only
        base_logger.add_device(
          EventHub::Components::Logger.logstash_cloud(Configuration.name,
            Configuration.environment)
        )
      else
        base_logger.add_device(Logger.new($stdout))
        base_logger.add_device(
          EventHub::Components::Logger.logstash(Configuration.name,
            Configuration.environment)
        )
      end

      @logger = LoggerProxy.new(base_logger)
    end
    @logger
  end
end
