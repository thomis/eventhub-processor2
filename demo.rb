require_relative 'lib/eventhub/processor2'

module Eventhub
  class Demo < Eventhub::Processor2

    def handle_message(message, args)
      # your code here.....
    end

    def version
      '10.1.1'
    end

  end
end

require 'json'
puts ARGV.to_json

processor = Eventhub::Demo.new
puts processor.name
puts processor.version
puts processor.environment
puts processor.detached
puts processor.configuration_file
processor.start
