# Eventhub module
module Eventhub
  # Heartbeat class
  class Heartbeat
    def start
      loop do
        Eventhub.logger.info('hearbeat')
        sleep Configuration.processor[:heartbeat_cycle_in_s]
      end
    end
  end
end
