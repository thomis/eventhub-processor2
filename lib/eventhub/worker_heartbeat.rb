# Eventhub module
module Eventhub
  # Heartbeat class
  class WorkerHeartbeat < Worker
    register(:heartbeat)

    def start
      @thread = Thread.new do
        loop do
          Eventhub.logger.info('hearbeat')
          sleep Configuration.processor[:heartbeat_cycle_in_s]
        end
      end
    end

    def stop
      @thread.exit
      @@queue_terminated << :heartbeat
    end
  end
end
