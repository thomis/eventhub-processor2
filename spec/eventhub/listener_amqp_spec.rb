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

  it "returns nil from publish to prevent return value leaking" do
    result = listener.publish(message: EventHub::Message.new.to_json)
    expect(result).to be_nil
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

  describe "#handle_payload correlation_id propagation" do
    it "passes the inbound correlation_id to the publisher" do
      payload = EventHub::Message.new.to_json
      expect(listener.wrapped_object).to receive(:publish).with(hash_including(correlation_id: "inbound-cid"))
      listener.handle_payload(payload: payload, correlation_id: "inbound-cid")
    end

    it "falls back to execution_id as correlation_id when none provided" do
      EventHub::CorrelationId.clear
      message = EventHub::Message.new
      expect(listener.wrapped_object).to receive(:publish).with(hash_including(correlation_id: message.process_execution_id))
      listener.handle_payload(payload: message.to_json)
    end
  end
end

# Cleanup tolerance — uses .allocate to avoid poking fakes into a live
# Celluloid actor whose finalizer would fire later during Celluloid.shutdown.
RSpec.describe "EventHub::ActorListenerAmqp#cleanup" do
  before(:all) do
    EventHub::Configuration.load!
  end

  let(:bare) do
    l = EventHub::ActorListenerAmqp.allocate
    l.instance_variable_set(:@connections, {})
    l
  end

  it "tolerates a connection#close that raises" do
    fake_connection = instance_double(Bunny::Session)
    allow(fake_connection).to receive(:close).and_raise(Bunny::ConnectionClosedError.new("torn down"))
    bare.instance_variable_set(:@connections, {"q" => fake_connection})
    expect { bare.cleanup }.not_to raise_error
  end

  it "returns early when no connections were registered" do
    bare.instance_variable_set(:@connections, nil)
    expect { bare.cleanup }.not_to raise_error
  end
end

# Hooks-level coverage isolated from the live integration listener above.
# We instantiate the underlying class via .allocate, fully stub the AMQP
# layer, and drive #listen synchronously to exercise the registered callbacks.
RSpec.describe "EventHub::ActorListenerAmqp listen hooks" do
  before(:all) do
    EventHub::Configuration.load!
  end

  # default: connection open, on_uncaught_exception yields a non-recoverable
  # error, on_cancellation fires. Tests override these per-scenario.
  let(:uncaught_exception) { RuntimeError.new("kaboom") }
  let(:connection_open) { true }
  let(:fake_connection) do
    c = instance_double(Bunny::Session)
    allow(c).to receive(:start)
    allow(c).to receive(:on_blocked).and_yield("low memory")
    allow(c).to receive(:on_unblocked).and_yield
    allow(c).to receive(:close)
    allow(c).to receive(:open?).and_return(connection_open)
    c
  end
  let(:fake_channel) do
    ch = instance_double(Bunny::Channel)
    allow(ch).to receive(:prefetch)
    allow(ch).to receive(:on_uncaught_exception).and_yield(uncaught_exception, nil)
    ch
  end
  let(:fake_queue) do
    q = instance_double(Bunny::Queue)
    allow(q).to receive(:subscribe_with)
    q
  end
  let(:fake_consumer) do
    cons = double("consumer")
    allow(cons).to receive(:on_cancellation).and_yield
    allow(cons).to receive(:on_delivery)
    cons
  end

  let(:bare_listener) do
    l = EventHub::ActorListenerAmqp.allocate
    l.instance_variable_set(:@connections, {})
    l.instance_variable_set(:@processor_instance, nil)
    allow(l).to receive(:create_bunny_connection).and_return(fake_connection)
    l
  end

  before do
    allow(fake_connection).to receive(:create_channel).and_return(fake_channel)
    allow(fake_channel).to receive(:queue).and_return(fake_queue)
    allow(EventHub::Consumer).to receive(:new).and_return(fake_consumer)
  end

  it "logs on_blocked / on_unblocked events" do
    messages = []
    allow(EventHub.logger).to receive(:warn) { |m| messages << [:warn, m] }
    allow(EventHub.logger).to receive(:info) { |m| messages << [:info, m] }
    allow(EventHub.logger).to receive(:error) { |m| messages << [:error, m] }
    allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp).and_return(nil)

    bare_listener.listen(queue_name: "test-q", index: 0)

    expect(messages.any? { |lvl, m| lvl == :warn && m.to_s.include?("Broker blocked") }).to be(true)
    expect(messages.any? { |lvl, m| lvl == :info && m.to_s.include?("Broker unblocked") }).to be(true)
  end

  context "on_uncaught_exception with a non-recoverable error (connection open)" do
    let(:uncaught_exception) { RuntimeError.new("user-code bug") }
    let(:connection_open) { true }

    it "logs an error and restarts the listener" do
      fake_async = double("async")
      restart_calls = 0
      allow(fake_async).to receive(:restart) { restart_calls += 1 }
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp)
        .and_return(double("proxy", async: fake_async))

      bare_listener.listen(queue_name: "test-q", index: 0)
      expect(restart_calls).to be >= 1
    end
  end

  context "on_uncaught_exception with a recoverable Bunny error" do
    let(:uncaught_exception) { Bunny::NetworkFailure.new("broker bounced", nil) }
    let(:connection_open) { false }

    it "logs a warning but does NOT restart (lets Bunny auto-recovery handle it)" do
      messages = []
      allow(EventHub.logger).to receive(:warn) { |m| messages << m.to_s }
      allow(EventHub.logger).to receive(:info)
      allow(EventHub.logger).to receive(:error)

      restart_calls = 0
      fake_async = double("async")
      allow(fake_async).to receive(:restart) { restart_calls += 1 }
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp)
        .and_return(double("proxy", async: fake_async))

      bare_listener.listen(queue_name: "test-q", index: 0)

      expect(messages.any? { |m| m =~ /recoverable.*leaving recovery to Bunny/ }).to be(true)
      expect(restart_calls).to eq(0)
    end
  end

  context "on_cancellation when the connection is still open" do
    let(:uncaught_exception) { RuntimeError.new("user-code bug") }
    let(:connection_open) { true }

    it "restarts (real broker-side cancel: queue deleted / policy change)" do
      fake_async = double("async")
      restart_calls = 0
      allow(fake_async).to receive(:restart) { restart_calls += 1 }
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp)
        .and_return(double("proxy", async: fake_async))

      bare_listener.listen(queue_name: "test-q", index: 0)
      # both hooks (uncaught + cancellation) fire restart in this scenario
      expect(restart_calls).to be >= 2
    end
  end

  context "on_cancellation when the connection is closed (mid-disconnect)" do
    let(:uncaught_exception) { Bunny::NetworkFailure.new("dropped", nil) }
    let(:connection_open) { false }

    it "does NOT restart (lets Bunny re-register the consumer on reconnect)" do
      restart_calls = 0
      fake_async = double("async")
      allow(fake_async).to receive(:restart) { restart_calls += 1 }
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp)
        .and_return(double("proxy", async: fake_async))

      bare_listener.listen(queue_name: "test-q", index: 0)
      expect(restart_calls).to eq(0)
    end
  end

  it "re-raises and logs when with_listen itself fails" do
    allow(bare_listener).to receive(:create_bunny_connection).and_raise("connection refused")
    expect(EventHub.logger).to receive(:error).with(/Unexpected exception/).at_least(:once)
    expect { bare_listener.listen(queue_name: "test-q", index: 0) }.to raise_error(/connection refused/)
  end
end
