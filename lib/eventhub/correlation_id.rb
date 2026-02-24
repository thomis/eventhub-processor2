# EventHub module
module EventHub
  # Manages correlation_id for distributed tracing
  # Storage mechanism can be swapped if needed (e.g., Thread.current -> Fiber storage)
  module CorrelationId
    class << self
      def current
        Thread.current[:eventhub_correlation_id]
      end

      def current=(value)
        Thread.current[:eventhub_correlation_id] = value
      end

      def clear
        Thread.current[:eventhub_correlation_id] = nil
      end

      # Execute block with correlation_id set, ensures cleanup
      def with(correlation_id)
        if correlation_id.nil? || correlation_id.to_s.empty?
          yield
        else
          old_value = current
          begin
            self.current = correlation_id
            yield
          ensure
            self.current = old_value
          end
        end
      end
    end
  end
end
