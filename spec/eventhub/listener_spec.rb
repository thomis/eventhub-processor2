require "spec_helper"

RSpec.describe EventHub::ActorListener do
  before(:all) do
    Support.ensure_rabbitmq_is_available
  end

  let!(:listener) {
    EventHub::ActorListener.new(EventHub::Processor2.new)
  }

  it "gives a valid actor" do
    # due to rspec caching better to create instance within the test
    expect(listener).not_to eq(nil)
  end

  it "succeeds to publish message" do
    expect { listener.publish(message: EventHub::Message.new.to_json) }.not_to raise_error
  end

  it "succeeds to publish message to different exchange" do
    expect { listener.publish(message: EventHub::Message.new.to_json, exchange_name: "an_exchange") }.not_to raise_error
  end

  it "raises exception when restart" do
    expect(listener).not_to eq(nil)
    expect { listener.restart }.to raise_error(RuntimeError, "Listener is restarting...")
  end

  it "handles payload" do
    payload = EventHub::Message.new.to_json
    expect { listener.handle_payload(payload: payload) }.not_to raise_error
  end

  it "handles invalid payload" do
    payload = "{]"
    expect { listener.handle_payload(payload: payload) }.not_to raise_error
  end
end
