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
      channel.confirm_select
      exchange = channel.direct(exchange_name, durable: true)

      exchange.publish(message, persistent: true)
      success = channel.wait_for_confirms

      unless success
        raise "Published message from Listener actor " \
              "has not been confirmed by the server"
      end
    ensure
      channel&.close
    end

    def cleanup
      EventHub.logger.info("Publisher is cleaning up...")
      @connection&.close
    end
  end
end
