# EventHub module
module EventHub
  # Heartbeat class
  class ActorPublisher
    include Celluloid
    include Helper
    finalizer :cleanup

    def initialize(processor_instance)
      @processor_instance = processor_instance
      EventHub.logger.info('Publisher is starting...')

      @connection = create_bunny_connection
      @connection.start
    end

    def publish(args = {})
      message = args[:message]
      return if message.nil?

      exchange_name = args[:exchange_name] || EH_X_INBOUND

      channel = @connection.create_channel
      channel.confirm_select
      exchange = channel.direct(exchange_name, durable: true)

      exchange.publish(message, persistent: true)
      success = channel.wait_for_confirms

      unless success
        raise 'Published message from Listener actor '\
              'has not been confirmed by the server'
      end
      ensure
        channel.close if channel
    end

    def cleanup
      EventHub.logger.info('Publisher is cleanig up...')
      @connection.close if @connection
    end
  end
end
