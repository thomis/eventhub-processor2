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
      @channel = nil
    end

    def publish(args = {})
      ensure_channel

      message = args[:message]
      return if message.nil?

      exchange_name = args[:exchange_name] || EH_X_INBOUND
      exchange = @channel.direct(exchange_name, durable: true)

      publish_options = {persistent: true}
      correlation_id = args[:correlation_id] || CorrelationId.current
      publish_options[:correlation_id] = correlation_id if correlation_id

      exchange.publish(message, publish_options)
      nil
    rescue Bunny::NetworkFailure, Bunny::ChannelAlreadyClosed => e
      # broker-side close - drop the channel so next publish reopens it
      EventHub.logger.warn("Publisher channel dropped: #{e.class}: #{e.message}")
      begin
        @channel&.close
      rescue
        nil
      end
      @channel = nil
      raise
    end

    def cleanup
      EventHub.logger.info("Publisher is cleaning up...")
      begin
        @channel&.close
      rescue => ex
        EventHub.logger.warn("Publisher cleanup channel: ignoring #{ex.class}: #{ex.message}")
      end
      begin
        @connection&.close
      rescue => ex
        EventHub.logger.warn("Publisher cleanup connection: ignoring #{ex.class}: #{ex.message}")
      end
    end

    private

    def ensure_channel
      unless @connection
        @connection = create_bunny_connection
        @connection.start
      end
      return if @channel&.open?

      attempts = 0
      begin
        @channel = @connection.create_channel
        @channel.confirm_select(tracking: true)
      rescue Bunny::NetworkFailure, Bunny::ChannelAlreadyClosed
        attempts += 1
        if attempts < 3
          sleep 1
          retry
        end
        raise
      end
    end
  end
end
