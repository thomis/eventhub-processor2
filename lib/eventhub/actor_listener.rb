# EventHub module
module EventHub
  # Listner Class
  class ActorListener
    include Celluloid
    include Helper
    finalizer :cleanup

    def initialize(processor_instance)
      @actor_watchdog = ActorWatchdog.new_link
      @connections= {}
      @processor_instance = processor_instance
      start
    end

    def start
      EventHub.logger.info('Listener is starting...')
      EventHub::Configuration.processor[:listener_queues].each_with_index do |queue_name, index|
        async.listen(queue_name: queue_name, index: index)
      end
    end

    def restart
      raise 'Listener is restarting..'
    end

    def listen(args = {})
      queue_name = args[:queue_name]

      connection = Bunny.new(bunny_connection_properties)
      @connections[queue_name] = connection
      connection.start

      channel = connection.create_channel
      channel.prefetch(1)
      queue = channel.queue(queue_name, durable: true)

      consumer = EventHub::Consumer.new(channel,
                                        queue,
                                        EventHub::Configuration.name + '-' + args[:index].to_s,
                                        false)

      EventHub.logger.info("Listening to queue [#{queue_name}]")
      consumer.on_delivery do |delivery_info, metadata, payload|
        EventHub.logger.info("#{queue_name}: [#{delivery_info.delivery_tag}] delivery")

        @processor_instance.statistics.measure(payload.size) do
          message = EventHub::Message.from_json(payload)
          response_messages = @processor_instance.send(:handle_message, message, {})

          Array(response_messages).each do |message|
            publish(connection, message.to_json)
          end

          channel.acknowledge(delivery_info.delivery_tag, false)
        end

        EventHub.logger.info("#{queue_name}: [#{delivery_info.delivery_tag}] acknowledged")
      end

      queue.subscribe_with(consumer, block: false)
    end

    def publish(connection, message)
      channel = connection.create_channel
      channel.confirm_select
      exchange = channel.direct(EventHub::EH_X_INBOUND, durable: true)
      exchange.publish(message, persistent: true)
      success = channel.wait_for_confirms
      if !success
        raise 'Published message from Listener actor has not been confirmed by the server'
      end
    ensure
      channel.close
    end

    def cleanup
      EventHub.logger.info('Listener is cleanig up...')

      @connections.values.each do |connection|
        connection.close if connection
      end
    end

  end
end
