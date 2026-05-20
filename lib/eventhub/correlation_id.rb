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

      # Execute block with correlation_id set, ensures cleanup.
      #
      # Always saves the prior value and restores it on exit, even when
      # called with nil/empty - otherwise any value written to `current`
      # inside the block (e.g. handle_payload's fallback to the message
      # body's execution_id) would leak onto the consumer thread and be
      # picked up by the next message's processing.
      def with(correlation_id)
        old_value = current
        begin
          self.current = correlation_id unless correlation_id.nil? || correlation_id.to_s.empty?
          yield
        ensure
          self.current = old_value
        end
      end
    end
  end
end
