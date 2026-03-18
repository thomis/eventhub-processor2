require_relative "../lib/eventhub/base"

module EventHub
  class Receiver < Processor2
    def version
      "2.0.0"
    end

    def company_name
      "Example Company"
    end

    # Custom README served via method instead of file
    def readme_as_html
      <<~HTML
        <h1>Receiver Processor</h1>
        <p>This processor receives messages and deletes associated files.</p>
        <h2>Features</h2>
        <ul>
          <li>Receives messages from the queue</li>
          <li>Deletes files based on message ID</li>
          <li>Logs all operations</li>
        </ul>
        <h2>Configuration</h2>
        <p>No special configuration required.</p>
      HTML
    end

    # Custom CHANGELOG served via method instead of file
    def changelog_as_html
      <<~HTML
        <h1>Changelog</h1>
        <h2>[2.0.0] 2026-01-18</h2><ul>
          <li>Added custom documentation via methods</li>
          <li>Improved error handling</li>
        </ul>
        <h2>[1.0.0] 2025-01-01</h2><ul>
          <li>Initial release</li>
        </ul>
      HTML
    end

    def handle_message(message, args = {})
      id = message.body["id"]
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
