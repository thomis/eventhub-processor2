# Eventhub module
module Eventhub
  # Watchdog class
  class WorkerWatchdog < Worker
    register(:watchdog)

    def start
      @thread = Thread.new do
        loop do
          Eventhub.logger.info('watchdog')
          watch
          sleep Configuration.processor[:watchdog_cycle_in_s]
        end
      end
    end

    def stop
      @thread.exit
      @@queue_terminated << :watchdog
    end

    private

    def watch
      server = Eventhub::Configuration.server
      connection = Bunny.new(Eventhub::Helper.bunny_connection_properties)
      connection.start

      Eventhub::Configuration.processor[:listener_queues].each do |queue_name|
        unless connection.queue_exists?(queue_name)
          Eventhub.logger.warn("Unable to find queue [#{queue_name}]")
        end
      end

    ensure
      connection.close if connection
    end
  end
end
