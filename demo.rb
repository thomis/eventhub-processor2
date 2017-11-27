require_relative 'lib/eventhub/processor2'

module Eventhub
  # Demo class
  class Demo < Eventhub::Processor2
    def handle_message(message, args)
      # your code here.....
    end

    def version
      '10.1.1'
    end
  end
end

Eventhub::Demo.new.start
