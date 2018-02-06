# EventHub module
module EventHub
  # Sleep Class which can interrupt running sleep
  class Sleeper
    def start(seconds)
      @reader, @writer = IO.pipe
      IO.select([@reader], nil, nil, seconds)
    end

    def stop
      @writer.close if @writer and !@writer.closed?
    end
  end
end
