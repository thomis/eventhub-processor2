# Eventhub module
module Eventhub
  # Heartbeat class
  class Consumer < Bunny::Consumer

    def handle_cancellation(_)
      Eventhub.logger.error("Consumer reports cancellation")
    end

  end
end
