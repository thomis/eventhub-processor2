require "spec_helper"
require "fileutils"

RSpec.describe EventHub::Processor2 do
  before(:all) do
    Support.ensure_rabbitmq_is_available
  end

  let!(:processor) {
    EventHub::Processor2.new
  }

  it "has a version number" do
    expect(EventHub::VERSION).not_to be nil
  end

  it "gets a version" do
    expect(processor.version).not_to eq(nil)
  end

  it "get configuration file" do
    expect(EventHub::Configuration.config_file).to match(/config\/processor2.json$/)
  end

  it "raises exception if handle_message method is not implemented" do
    expect { processor.handle_message("msg") }.to raise_error(RuntimeError)
  end

  it "starts and stops" do
    thr = Thread.new { processor.start }
    sleep 0.5
    processor.stop
    thr.join
    expect(true).to eq(true)
  end

  describe "#publish correlation_id propagation across actors" do
    let(:fake_listener) { double("listener_actor") }

    before do
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp).and_return(fake_listener)
    end

    after do
      EventHub::CorrelationId.clear
    end

    it "captures CorrelationId.current from the caller thread into args" do
      EventHub::CorrelationId.current = "caller-thread-cid"
      expect(fake_listener).to receive(:publish).with(hash_including(correlation_id: "caller-thread-cid"))
      processor.publish(message: "m")
    end

    it "does not override an explicit correlation_id from args" do
      EventHub::CorrelationId.current = "thread-cid"
      expect(fake_listener).to receive(:publish).with(hash_including(correlation_id: "explicit-cid"))
      processor.publish(message: "m", correlation_id: "explicit-cid")
    end

    it "passes args unchanged when no thread-local correlation_id is set" do
      EventHub::CorrelationId.clear
      expect(fake_listener).to receive(:publish) do |args|
        expect(args).not_to have_key(:correlation_id)
      end
      processor.publish(message: "m")
    end

    it "logs and re-raises if the underlying publish raises" do
      EventHub::CorrelationId.clear
      allow(fake_listener).to receive(:publish).and_raise("publish blew up")
      expect(EventHub.logger).to receive(:error).with(/Unexpected exeption while publish/)
      expect { processor.publish(message: "m") }.to raise_error(/publish blew up/)
    end
  end
end
