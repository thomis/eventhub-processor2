require_relative '../lib/eventhub/processor2'

module Eventhub
  # Demo class
  class Example < Eventhub::Processor2
    def handle_message(message, args)
      # your code here.....
    end

    def version
      '10.1.1'
    end
  end
end

Eventhub::Example.new.start


# connection =Bunny.new(port: 32777)
# connection.start
# channel = connection.create_channel
# channel.queue("example", :durable => true, :auto_delete => false)
# connection.close
