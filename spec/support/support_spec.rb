require "bunny"

RSpec.describe Support do
  describe ".ensure_rabbitmq_is_available" do
    let(:mock_bunny) { instance_double(Bunny::Session) }

    before do
      allow(Bunny).to receive(:new).and_return(mock_bunny)
      allow(mock_bunny).to receive(:start)
    end

    it "connects to RabbitMQ successfully" do
      expect(Bunny).to receive(:new).with(vhost: "event_hub", user: "guest", password: "guest").and_return(mock_bunny)
      expect(mock_bunny).to receive(:start).once

      Support.ensure_rabbitmq_is_available
    end

    it "retries if connection fails" do
      attempt = 0
      allow(mock_bunny).to receive(:start) do
        attempt += 1
        raise StandardError if attempt < 3
      end

      expect(Support).to receive(:sleep).with(1).twice  # Expect sleep to happen twice before success
      expect { Support.ensure_rabbitmq_is_available }.not_to raise_error
    end

    it "gives up after the maximum number of attempts" do
      allow(mock_bunny).to receive(:start).and_raise(StandardError, "connection reset")
      allow(Support).to receive(:sleep)

      expect { Support.ensure_rabbitmq_is_available(max_attempts: 3) }
        .to raise_error(RuntimeError, "RabbitMQ not available after 3 attempts: connection reset")
      expect(mock_bunny).to have_received(:start).exactly(3).times
      expect(Support).to have_received(:sleep).with(1).twice
    end
  end
end
