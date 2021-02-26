# EventHub module
module EventHub
  # Listner Class
  class ActorListener
    include Celluloid
    include Helper
    finalizer :cleanup

    def initialize(processor_instance)
      @actor_publisher = ActorPublisher.new_link
      @actor_watchdog = ActorWatchdog.new_link
      @connections = {}
      @processor_instance = processor_instance
      start
    end

    def start
      EventHub.logger.info("Listener is starting...")
      EventHub::Configuration.processor[:listener_queues].each_with_index do |queue_name, index|
        async.listen(queue_name: queue_name, index: index)
      end
    end

    def restart
      raise "Listener is restarting..."
    end

    def listen(args = {})
      with_listen(args) do |connection, channel, consumer, queue, queue_name|
        EventHub.logger.info("Listening to queue [#{queue_name}]")
        consumer.on_delivery do |delivery_info, metadata, payload|
          EventHub.logger.info("#{queue_name}: [#{delivery_info.delivery_tag}]"\
                                 " delivery")

          @processor_instance.statistics.measure(payload.size) do
            handle_payload(payload: payload,
                           connection: connection,
                           queue_name: queue_name,
                           content_type: metadata[:content_type],
                           priority: metadata[:priority],
                           delivery_tag: delivery_info.delivery_tag)
            channel.acknowledge(delivery_info.delivery_tag, false)
          end

          EventHub.logger.info("#{queue_name}: [#{delivery_info.delivery_tag}]"\
                               " acknowledged")
        end
        queue.subscribe_with(consumer, block: false)
      end
    rescue => error
      EventHub.logger.error("Unexpected exception: #{error}. It should restart now with this exception...")
      raise
    end

    def with_listen(args = {}, &block)
      connection = create_bunny_connection
      connection.start
      queue_name = args[:queue_name]
      @connections[queue_name] = connection
      channel = connection.create_channel
      channel.prefetch(1)
      queue = channel.queue(queue_name, durable: true)
      consumer = EventHub::Consumer.new(channel,
        queue,
        EventHub::Configuration.name +
          "-" +
          args[:index].to_s,
        false)
      yield connection, channel, consumer, queue, queue_name
    end

    def handle_payload(args = {})
      response_messages = []
      connection = args[:connection]

      # convert to EventHub message
      message = EventHub::Message.from_json(args[:payload])

      # append to execution history
      message.append_to_execution_history(EventHub::Configuration.name)

      # return invalid messages to dispatcher
      if message.invalid?
        response_messages << message
        EventHub.logger.info("-> #{message} => return invalid to dispatcher")
      else
        begin
          response_messages = @processor_instance.send(:handle_message,
            message,
            pass_arguments(args))
        rescue => exception
          # this catches unexpected exceptions in handle message method
          # deadletter the message via dispatcher
          message.status_code = EventHub::STATUS_DEADLETTER
          message.status_message = exception.to_s
          EventHub.logger.info("-> #{message} => return exception to dispatcher")
          response_messages << message
        end
      end

      Array(response_messages).each do |message|
        publish(message: message.to_json, connection: connection)
      end
    end

    def pass_arguments(args = {})
      keys_to_pass = [:queue_name, :content_type, :priority, :delivery_tag]
      args.select { |key| keys_to_pass.include?(key) }
    end

    def cleanup
      EventHub.logger.info("Listener is cleaning up...")
      # close all open connections
      return unless @connections
      @connections.values.each do |connection|
        connection&.close
      end
    end

    def publish(args)
      @actor_publisher.publish(args)
    end
  end
end
