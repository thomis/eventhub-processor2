# Eventhub module
module Eventhub
  # Base worker class
  class Worker
    WORKER = {}
    MAX_STOP_TIME_IN_S = 3

    # queue to indicate successful worker termination
    @@queue_terminated = Queue.new

    def self.register(name)
      WORKER[name] = new
    end

    def self.start
      WORKER.values.each(&:start)
    end

    def self.stop
      WORKER.values.each(&:stop)
      wait_for_stop
    end

    def self.restart
      stop
      start
    end

    def self.wait_for_stop
      workers = WORKER.keys
      start = Time.now

      # as long as we have running workers and below time limit
      while !workers.empty? && below_time_limit?(start)
        if @@queue_terminated.empty?
          sleep 0.2
        else
          workers.delete(@@queue_terminated.pop)
        end
      end
      msg = "Worker(s) [#{workers.join(', ')}]: "
      msg += "did not stop within #{MAX_STOP_TIME_IN_S} seconds"
      Eventhub.logger.warn(msg) unless workers.empty?
    end

    def self.below_time_limit?(start)
      (Time.now - start) < MAX_STOP_TIME_IN_S
    end

    private_class_method :wait_for_stop
    private_class_method :below_time_limit?
  end
end
