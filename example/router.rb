require_relative "../lib/eventhub/base"

module EventHub
  # Demo class
  class Router < Processor2
    def handle_message(message, args = {})
      id = message.body["id"]
      EventHub.logger.info("Received: [#{id}]")
      publish(message: message.to_json, exchange_name: "example.inbound")
      EventHub.logger.info("Returned: [#{id}]")
      nil
    end
  end
end

EventHub::Router.new.start
