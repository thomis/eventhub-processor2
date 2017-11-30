module Eventhub
  class Worker
    WORKER = {}
    MAX_STOP_TIME_IN_S = 3

    # queue to indicate successful worker termination
    @@queue_terminated = Queue.new

    def self.register(name)
      WORKER[name] = self.new
    end

    def self.start
      WORKER.values.each do |worker|
        worker.start
      end
    end

    def self.stop
      WORKER.values.each do |worker|
        worker.stop
      end
      wait_for_stop
    end

    def self.wait_for_stop
      workers = WORKER.keys
      start = Time.now

      # as long as we have running workers and time below max stop time
      while !workers.empty?  && (Time.now - start < MAX_STOP_TIME_IN_S)
        if @@queue_terminated.size > 0
          workers.delete(@@queue_terminated.pop)
        else
          sleep 0.2
        end
      end
      msg = "Worker(s) [#{workers.join(', ')}]: "
      msg += "did not stop within #{MAX_STOP_TIME_IN_S} seconds"
      Eventhub.logger.warn(msg) unless workers.empty?
    end

    def self.restart
      stop
      start
    end
  end
end
