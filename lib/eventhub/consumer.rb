# EventHub module
module EventHub
  # Heartbeat class
  class Consumer < Bunny::Consumer

    def handle_cancellation(_)
      EventHub.logger.error("Consumer reports cancellation")
    end

  end
end
