# EventHub module
module EventHub
  # Listner Class
  class ActorListenerAmqp
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
      server = EventHub::Configuration.server
      queues = EventHub::Configuration.processor[:listener_queues]
      settings = [
        server[:user],
        server[:host],
        server[:port],
        server[:vhost],
        "tls=#{server[:tls]}",
        queues.join(", ")
      ].join(", ")
      EventHub.logger.info("Listener amqp is starting [#{settings}]...")
      queues.each_with_index do |queue_name, index|
        async.listen(queue_name: queue_name, index: index)
      end
    end

    def restart
      raise "Listener amqp is restarting..."
    end

    def listen(args = {})
      with_listen(args) do |connection, channel, consumer, queue, queue_name|
        EventHub.logger.info("Listening to queue [#{queue_name}]")

        # log broker-initiated connection state changes
        connection.on_blocked { |reason| EventHub.logger.warn("Broker blocked connection: #{reason}") }
        connection.on_unblocked { EventHub.logger.info("Broker unblocked connection") }

        # Only escalate to an actor restart for exceptions Bunny will NOT
        # recover from. Transient network exceptions are handled by Bunny's
        # automatic recovery; an actor restart in that window races recovery
        # and incurs an avoidable 15s before_restart sleep without consumption.
        channel.on_uncaught_exception do |ex, _consumer|
          if recoverable_bunny_error?(ex)
            EventHub.logger.warn("Consumer thread raised recoverable #{ex.class}: #{ex.message} - leaving recovery to Bunny")
          else
            EventHub.logger.error("Consumer thread raised non-recoverable #{ex.class}: #{ex.message} - restarting listener")
            Celluloid::Actor[:actor_listener_amqp]&.async&.restart
          end
        end

        # Broker may cancel a consumer (queue deleted, HA failover, policy change).
        # If the connection is still open, this is a real broker-side cancel and
        # we must restart. If the connection is closed/recovering, Bunny will
        # re-register the consumer itself on reconnect; do not race it.
        consumer.on_cancellation do
          if connection.open?
            EventHub.logger.error("Consumer for [#{queue_name}] cancelled by broker - restarting listener")
            Celluloid::Actor[:actor_listener_amqp]&.async&.restart
          else
            EventHub.logger.warn("Consumer for [#{queue_name}] cancelled during disconnect - leaving recovery to Bunny")
          end
        end

        consumer.on_delivery do |delivery_info, metadata, payload|
          CorrelationId.with(metadata[:correlation_id]) do
            EventHub.logger.info("#{queue_name}: [#{delivery_info.delivery_tag}]" \
                                   " delivery")

            @processor_instance.statistics.measure(payload.size) do
              handle_payload(payload: payload,
                connection: connection,
                queue_name: queue_name,
                content_type: metadata[:content_type],
                priority: metadata[:priority],
                delivery_tag: delivery_info.delivery_tag,
                correlation_id: metadata[:correlation_id])
              channel.acknowledge(delivery_info.delivery_tag, false)
            end

            EventHub.logger.info("#{queue_name}: [#{delivery_info.delivery_tag}]" \
                                 " acknowledged")
          ensure
            ExecutionId.clear
            # Belt-and-suspenders: CorrelationId.with's ensure already
            # restores the prior value, but clearing here protects any
            # future code path that writes CorrelationId.current outside
            # of `.with` (e.g. handle_payload's fallback was the original
            # leak source pre-1.28.2).
            CorrelationId.clear
          end
        end
        queue.subscribe_with(consumer, block: false)
      end
    rescue => error
      EventHub.logger.error("Unexpected exception: #{error}. It should restart now with this exception...")
      raise
    end

    def with_listen(args = {}, &block)
      connection = create_bunny_connection
      queue_name = args[:queue_name]
      # store FIRST so cleanup can find a partially-started session
      @connections[queue_name] = connection
      connection.start
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
      correlation_id = args[:correlation_id] || CorrelationId.current

      # convert to EventHub message
      message = EventHub::Message.from_json(args[:payload])

      # set execution_id for logging
      ExecutionId.current = message.process_execution_id if message.valid?

      # use execution_id as correlation_id if not already set from AMQP metadata
      if CorrelationId.current.nil? && message.valid?
        CorrelationId.current = message.process_execution_id
        args[:correlation_id] ||= message.process_execution_id
      end

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

      # use possibly-updated execution_id fallback from above
      correlation_id ||= CorrelationId.current

      Array(response_messages).each do |message|
        next unless message.is_a?(EventHub::Message)
        publish(message: message.to_json, connection: connection, correlation_id: correlation_id)
      end
    end

    def pass_arguments(args = {})
      keys_to_pass = [:queue_name, :content_type, :priority, :delivery_tag, :correlation_id]
      args.select { |key| keys_to_pass.include?(key) }
    end

    def cleanup
      EventHub.logger.info("Listener amqp is cleaning up...")
      # close all open connections; bunny-3 can raise on a torn-down session
      return unless @connections
      @connections.values.each do |connection|
        connection&.close
      rescue => ex
        EventHub.logger.warn("Listener cleanup: ignoring #{ex.class}: #{ex.message}")
      end
    end

    def publish(args)
      @actor_publisher.publish(args)
    end

    # Exceptions that Bunny's network recovery handles transparently. If one of
    # these bubbles into `on_uncaught_exception`, the right move is to let the
    # in-flight recovery complete rather than racing it with an actor restart.
    RECOVERABLE_BUNNY_ERRORS = [
      Bunny::NetworkFailure,
      Bunny::ConnectionClosedError,
      Bunny::TCPConnectionFailed,
      Bunny::TCPConnectionFailedForAllHosts,
      Timeout::Error,
      IOError
    ].freeze

    def recoverable_bunny_error?(ex)
      RECOVERABLE_BUNNY_ERRORS.any? { |klass| ex.is_a?(klass) }
    end
  end
end
