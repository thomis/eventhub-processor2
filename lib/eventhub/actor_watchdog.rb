# EventHub module
module EventHub
  # Watchdog class
  class ActorWatchdog
    include Celluloid
    include Helper
    finalizer :cleanup

    def initialize
      async.start
    end

    def start
      loop do
        EventHub.logger.info('Running watchdog...')
        watch
        sleep Configuration.processor[:watchdog_cycle_in_s]
      end
    end

    def cleanup
      EventHub.logger.info('Watchdog is cleanig up...')
    end

    private

    def watch
      connection = create_bunny_connection
      connection.start

      EventHub::Configuration.processor[:listener_queues].each do |queue_name|
        unless connection.queue_exists?(queue_name)
          EventHub.logger.warn("Queue [#{queue_name}] is missing")
          raise "Queue [#{queue_name}] is missing"
        end
      end
    ensure
      connection.close if connection
    end
  end
end
