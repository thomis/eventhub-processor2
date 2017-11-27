# Eventhub module
module Eventhub
  # Listner Class
  class Listener

    def initialize(args = {})
      @configuration = args[:configuration]
    end

    def start
      loop do
         puts 'is listening...'
        sleep 5
      end
    end
  end
end
