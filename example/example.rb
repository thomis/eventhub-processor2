require_relative '../lib/eventhub'

module EventHub
  # Demo class
  class Example < Processor2
    def handle_message(message, _args)
      id = message.body['id']
      name = "data/#{id}.json"

      begin
        File.delete(name)
      rescue => ex
        EventHub.logger.warn("File [#{name}]: #{ex}")
      end

      { body: { id: id, message: 'has been done' }}
    end

    def version
      '10.1.1'
    end
  end
end

EventHub::Example.new.start
