# EventHub module
module EventHub
  # Heartbeat class
  class ActorHeartbeat
    include Celluloid
    include Helper

    finalizer :cleanup

    def initialize(processor_instance)
      @processor_instance = processor_instance
      @connection = nil
      @channel = nil
      async.start
    end

    def start
      cycle = Configuration.processor[:heartbeat_cycle_in_s]
      EventHub.logger.info("Heartbeat is starting [cycle: #{cycle}s]...")

      every(60 * 60 * 24) { EventHub.logger.info("Actual actors: #{Celluloid::Actor.all.size}: #{Celluloid::Actor.all.map { |a| a.class }.join(", ")}") }

      publish(heartbeat(action: "started"))
      EventHub.logger.info("Heartbeat has sent [started] beat")
      loop do
        sleep Configuration.processor[:heartbeat_cycle_in_s]
        publish(heartbeat)
      end
    end

    def cleanup
      EventHub.logger.info("Heartbeat is cleaning up...")
      begin
        publish(heartbeat(action: "stopped"))
        EventHub.logger.info("Heartbeat has sent a [stopped] beat")
      rescue => ex
        EventHub.logger.warn("Heartbeat cleanup publish: ignoring #{ex.class}: #{ex.message}")
      end
      begin
        @channel&.close
      rescue => ex
        EventHub.logger.warn("Heartbeat cleanup channel: ignoring #{ex.class}: #{ex.message}")
      end
      begin
        @connection&.close
      rescue => ex
        EventHub.logger.warn("Heartbeat cleanup connection: ignoring #{ex.class}: #{ex.message}")
      end
    end

    private

    def publish(message)
      ensure_channel
      exchange = @channel.direct(EventHub::EH_X_INBOUND, durable: true)
      exchange.publish(message, persistent: true)
    rescue Bunny::NetworkFailure, Bunny::ChannelAlreadyClosed => e
      EventHub.logger.warn("Heartbeat channel dropped: #{e.class}: #{e.message}")
      begin
        @channel&.close
      rescue
        nil
      end
      @channel = nil
      raise
    end

    def ensure_channel
      unless @connection
        @connection = create_bunny_connection
        @connection.start
      end
      return if @channel&.open?
      @channel = @connection.create_channel
      @channel.confirm_select(tracking: true)
    end

    def heartbeat(args = {action: "running"})
      message = EventHub::Message.new
      message.origin_module_id = EventHub::Configuration.name
      message.origin_type = "processor"
      message.origin_site_id = "global"

      message.process_name = "event_hub.heartbeat"

      now = Time.now

      # message structure needs more changes
      message.body = {
        version: @processor_instance.send(:version),
        action: args[:action],
        pid: Process.pid,
        process_name: "event_hub.heartbeat",
        heartbeat: {
          started: now_stamp(started_at),
          stamp_last_beat: now_stamp(now),
          uptime_in_ms: (now - started_at) * 1000,
          heartbeat_cycle_in_ms: Configuration.processor[:heartbeat_cycle_in_s] * 1000,
          queues_consuming_from: EventHub::Configuration.processor[:listener_queues],
          queues_publishing_to: [EventHub::EH_X_INBOUND], # needs more dynamic in the future
          host: Socket.gethostname,
          addresses: addresses,
          messages: messages_statistics
        }
      }
      message.to_json
    end

    def started_at
      @processor_instance.started_at
    end

    def statistics
      @processor_instance.statistics
    end

    def addresses
      interfaces = Socket.getifaddrs.select { |interface|
        !interface.addr.ipv4_loopback? && !interface.addr.ipv6_loopback?
      }

      interfaces.map { |interface|
        begin
          {
            interface: interface.name,
            host_name: Socket.gethostname,
            ip_address: interface.addr.ip_address
          }
        rescue
          nil # will be ignored
        end
      }.compact
    end

    def messages_statistics
      {
        total: statistics.messages_total,
        successful: statistics.messages_successful,
        unsuccessful: statistics.messages_unsuccessful,
        average_size: statistics.messages_average_size,
        average_process_time_in_ms:
          statistics.messages_average_process_time * 1000,
        total_process_time_in_ms:
          statistics.messages_total_process_time * 1000
      }
    end
  end
end
