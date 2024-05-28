require_relative "../lib/eventhub/base"

module EventHub
  class Example < Processor2
    def version
      "1.0.0" # define your version
    end

    def handle_message(message, args = {})
      # deal with your parsed EventHub message
      # message.class => EventHub::Message
      puts message.process_name # or whatever you need to do

      # or if there is no message to return to event_hub.inbound queue
      nil # [] works as well
    end
  end
end

# start your processor instance
EventHub::Example.new.start
