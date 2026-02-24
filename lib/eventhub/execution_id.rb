# EventHub module
module EventHub
  # ExecutionId module for storing the current message's execution_id
  # in thread-local storage for distributed tracing.
  module ExecutionId
    class << self
      def current
        Thread.current[:eventhub_execution_id]
      end

      def current=(value)
        Thread.current[:eventhub_execution_id] = value
      end

      def clear
        Thread.current[:eventhub_execution_id] = nil
      end
    end
  end
end
