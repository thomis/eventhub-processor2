# EventHub module
module EventHub
  # Watchdog class
  class ActorWatchdog
    include Celluloid
    include Helper

    finalizer :cleanup

    # number of consecutive failed cycles before we raise to force a restart
    MISSING_QUEUE_THRESHOLD = 3

    def initialize
      cycle = Configuration.processor[:watchdog_cycle_in_s]
      EventHub.logger.info("Watchdog is starting [cycle: #{cycle}s]...")
      @consecutive_failures = 0
      async.start
    end

    def start
      loop do
        watch
        sleep Configuration.processor[:watchdog_cycle_in_s]
      end
    end

    def cleanup
      EventHub.logger.info("Watchdog is cleaning up...")
    end

    private

    def watch
      connection = create_bunny_connection
      connection.start

      missing = EventHub::Configuration.processor[:listener_queues].reject do |queue_name|
        connection.queue_exists?(queue_name)
      end

      if missing.empty?
        @consecutive_failures = 0
      else
        @consecutive_failures += 1
        EventHub.logger.warn("Watchdog: queue(s) missing #{missing.inspect} (#{@consecutive_failures}/#{MISSING_QUEUE_THRESHOLD})")
        if @consecutive_failures >= MISSING_QUEUE_THRESHOLD
          raise "Queue(s) missing for #{@consecutive_failures} consecutive cycles: #{missing.inspect}"
        end
      end
    rescue Bunny::NetworkFailure, Bunny::TCPConnectionFailed, Timeout::Error => ex
      # transient broker problems are auto-recovered by Bunny; don't fight it
      EventHub.logger.warn("Watchdog: transient broker error #{ex.class}: #{ex.message} - skipping cycle")
    ensure
      begin
        connection&.close
      rescue
        nil
      end
    end
  end
end
