require "spec_helper"

RSpec.describe EventHub::ActorListenerAmqp do
  before(:all) do
    Support.ensure_rabbitmq_is_available
  end

  let!(:listener) {
    EventHub::ActorListenerAmqp.new(EventHub::Processor2.new)
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

  it "succeeds to publish message with explicit correlation_id" do
    expect { listener.publish(message: EventHub::Message.new.to_json, correlation_id: "explicit-corr-123") }.not_to raise_error
  end

  it "succeeds to publish message with correlation_id from thread-local storage" do
    EventHub::CorrelationId.current = "thread-corr-456"
    expect { listener.publish(message: EventHub::Message.new.to_json) }.not_to raise_error
    EventHub::CorrelationId.clear
  end

  it "raises exception when restart" do
    expect(listener).not_to eq(nil)
    expect { listener.restart }.to raise_error(RuntimeError, "Listener amqp is restarting...")
  end

  it "handles payload" do
    payload = EventHub::Message.new.to_json
    expect { listener.handle_payload(payload: payload) }.not_to raise_error
  end

  it "uses execution_id as correlation_id fallback when no correlation_id in metadata" do
    EventHub::CorrelationId.clear
    message = EventHub::Message.new
    execution_id = message.process_execution_id
    payload = message.to_json

    listener.handle_payload(payload: payload)

    # After processing, correlation_id should have been set to execution_id
    # Note: it gets cleared after the CorrelationId.with block, so we test via args
    args = {payload: payload, correlation_id: nil}
    listener.handle_payload(args)
    expect(args[:correlation_id]).to eq(execution_id)
  end

  it "handles invalid payload" do
    payload = "{]"
    expect { listener.handle_payload(payload: payload) }.not_to raise_error
  end
end
