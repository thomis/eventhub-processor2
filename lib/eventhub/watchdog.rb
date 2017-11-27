# Eventhub module
module Eventhub
  # Watchdog class
  class Watchdog
    def start
      loop do
        Eventhub.logger.info('watchdog')
        sleep Configuration.processor[:watchdog_cycle_in_s]
      end
    end
  end
end
