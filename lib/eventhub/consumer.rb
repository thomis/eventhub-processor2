# EventHub module
module EventHub
  # Consumer class
  class Consumer < Bunny::Consumer
    def handle_cancellation(_)
      EventHub.logger.error("Consumer reports cancellation")
    end
  end
end
