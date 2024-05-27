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

      # args is a hash with currently following keys
      # => :queue_name (used when listening to multiple queues)
      # => :content_type
      # => :priority
      # => :delivery_tag

      # if an exception is raised in your code
      # it will be automatically catched by
      # the processor2 gem and returned
      # to the event_hub.inbound queue

      # it is possible to publish a message during message processing but it's a
      # good style to return one or multiple messages at end of handle_message
      publish(message: "your message as a string") # default exchange_name is 'event_hub.inbound'
      publish(message: "your message as string", exchange_name: "your_specfic_exchange")

      # at the end return one of
      message_to_return = message.copy # return message if sucessfull processing

      # or if you have multiple messages to return to event_hub.inbound queue
      [message_to_return, new_message1, new_message2]

      # or if there is no message to return to event_hub.inbound queue
      nil # [] works as well
    end
  end
end

# start your processor instance
EventHub::Example.new.start
