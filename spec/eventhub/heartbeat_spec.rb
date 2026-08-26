require "spec_helper"

RSpec.describe EventHub::ActorHeartbeat do
  before(:all) do
    EventHub::Configuration.load!
  end

  let(:processor) { EventHub::Processor2.new }

  let(:fake_exchange) { instance_double(Bunny::Exchange, publish: nil) }
  let(:fake_channel) do
    ch = instance_double(Bunny::Channel)
    allow(ch).to receive(:confirm_select).with(tracking: true)
    allow(ch).to receive(:open?).and_return(true)
    allow(ch).to receive(:direct).and_return(fake_exchange)
    allow(ch).to receive(:close)
    ch
  end
  let(:fake_connection) do
    c = instance_double(Bunny::Session)
    allow(c).to receive(:start)
    allow(c).to receive(:create_channel).and_return(fake_channel)
    allow(c).to receive(:close)
    c
  end

  let(:heartbeat) do
    # bypass async.start by avoiding the actor proxy chain
    hb = EventHub::ActorHeartbeat.allocate
    hb.instance_variable_set(:@processor_instance, processor)
    hb.instance_variable_set(:@connection, nil)
    hb.instance_variable_set(:@channel, nil)
    allow(hb).to receive(:create_bunny_connection).and_return(fake_connection)
    hb
  end

  describe "#start" do
    it "sends a started beat and then keeps beating every cycle" do
      hb = EventHub::ActorHeartbeat.allocate
      hb.instance_variable_set(:@processor_instance, processor)
      hb.instance_variable_set(:@connection, nil)
      hb.instance_variable_set(:@channel, nil)
      allow(hb).to receive(:every)
      # set AFTER the processor above is instantiated - Processor2.new runs
      # Configuration.load!, which would reset the cycle to its 300s default
      # and turn the loop below into a real 5-minute sleep
      EventHub::Configuration.config_data[:processor][:heartbeat_cycle_in_s] = 0
      allow(hb).to receive(:heartbeat).and_return("beat")
      calls = 0
      allow(hb).to receive(:publish) do
        calls += 1
        raise "stop-loop" if calls >= 3
      end

      expect { hb.start }.to raise_error("stop-loop")
      # 1st call: [started] beat, further calls: cyclic beats from the loop
      expect(calls).to eq(3)
    ensure
      EventHub::Configuration.load!
    end
  end

  describe "#publish (private)" do
    it "reuses a single channel across multiple beats" do
      expect(fake_connection).to receive(:create_channel).once.and_return(fake_channel)
      3.times { heartbeat.send(:publish, "beat") }
    end

    it "drops channel on Bunny::NetworkFailure and re-raises" do
      allow(fake_exchange).to receive(:publish).and_raise(Bunny::NetworkFailure.new("boom", nil))
      expect { heartbeat.send(:publish, "beat") }.to raise_error(Bunny::NetworkFailure)
      expect(heartbeat.instance_variable_get(:@channel)).to be_nil
    end

    it "drops channel on Bunny::ChannelAlreadyClosed and re-raises" do
      allow(fake_exchange).to receive(:publish).and_raise(Bunny::ChannelAlreadyClosed.new("closed", fake_channel))
      expect { heartbeat.send(:publish, "beat") }.to raise_error(Bunny::ChannelAlreadyClosed)
    end

    it "tolerates errors when closing the dropped channel" do
      allow(fake_exchange).to receive(:publish).and_raise(Bunny::NetworkFailure.new("boom", nil))
      allow(fake_channel).to receive(:close).and_raise("close failed")
      expect { heartbeat.send(:publish, "beat") }.to raise_error(Bunny::NetworkFailure)
    end
  end

  describe "#cleanup" do
    it "publishes a stopped beat and closes channel/connection" do
      heartbeat.send(:publish, "warmup")
      expect(fake_exchange).to receive(:publish).at_least(:once)
      expect(fake_channel).to receive(:close)
      expect(fake_connection).to receive(:close)
      heartbeat.cleanup
    end

    it "tolerates exceptions from publish during cleanup" do
      heartbeat.send(:publish, "warmup")
      allow(heartbeat).to receive(:publish).and_raise("publish failed")
      expect { heartbeat.cleanup }.not_to raise_error
    end

    it "tolerates exceptions from channel#close during cleanup" do
      heartbeat.send(:publish, "warmup")
      allow(fake_channel).to receive(:close).and_raise(Bunny::ConnectionClosedError.new("torn down"))
      expect { heartbeat.cleanup }.not_to raise_error
    end

    it "tolerates exceptions from connection#close during cleanup" do
      heartbeat.send(:publish, "warmup")
      allow(fake_connection).to receive(:close).and_raise(Bunny::NetworkFailure.new("torn down", nil))
      expect { heartbeat.cleanup }.not_to raise_error
    end
  end
end
