require_relative '../lib/eventhub/base'

module EventHub
  class Receiver < Processor2
    def handle_message(message, args = {})
      id = message.body['id']
      EventHub.logger.info("[#{id}] - Received")

      file_name = "data/#{id}.json"
      begin
        File.delete(file_name)
        EventHub.logger.info("[#{id}] - File has been deleted")
      rescue => error
        EventHub.logger.error("[#{id}] - Unable to delete File: #{error}")
      end

      nil
    end
  end
end

EventHub::Receiver.new.start
