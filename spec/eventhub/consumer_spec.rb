require "bunny"

RSpec.describe EventHub::Consumer do
  let(:channel) { instance_double(Bunny::Channel) }
  let(:queue) { instance_double(Bunny::Queue) }
  let(:logger) { instance_double(Logger) }

  before do
    allow(EventHub).to receive(:logger).and_return(logger)
    allow(logger).to receive(:error)
  end

  it "logs an error message when cancellation occurs" do
    consumer = described_class.new(channel, queue, "")

    expect(logger).to receive(:error).with("Consumer reports cancellation")

    consumer.handle_cancellation(nil)  # Simulate cancellation event
  end
end
