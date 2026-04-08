# EventHub module
module EventHub
  # Publisher class
  class ActorPublisher
    include Celluloid
    include Helper

    finalizer :cleanup

    def initialize
      EventHub.logger.info("Publisher is starting...")
      @connection = nil
    end

    def publish(args = {})
      # keep connection once established
      unless @connection
        @connection = create_bunny_connection
        @connection.start
      end

      message = args[:message]
      return if message.nil?

      exchange_name = args[:exchange_name] || EH_X_INBOUND

      channel = @connection.create_channel
      channel.confirm_select(tracking: true)
      exchange = channel.direct(exchange_name, durable: true)

      publish_options = {persistent: true}
      correlation_id = args[:correlation_id] || CorrelationId.current
      publish_options[:correlation_id] = correlation_id if correlation_id

      exchange.publish(message, publish_options)
      nil
    ensure
      channel&.close
    end

    def cleanup
      EventHub.logger.info("Publisher is cleaning up...")
      @connection&.close
    end
  end
end
