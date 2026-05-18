require "spec_helper"

RSpec.describe EventHub::ActorPublisher do
  before(:all) do
    EventHub::Configuration.load!
  end

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

  # Bypass Celluloid (.allocate) so this spec doesn't depend on Celluloid.boot
  # state from earlier specs and tested raises don't kill an actor mid-test.
  let(:publisher) do
    pub = EventHub::ActorPublisher.allocate
    pub.instance_variable_set(:@connection, nil)
    pub.instance_variable_set(:@channel, nil)
    allow(pub).to receive(:create_bunny_connection).and_return(fake_connection)
    pub
  end

  after(:each) do
    EventHub::CorrelationId.clear
  end

  describe "#publish (channel reuse)" do
    it "creates the channel only once across multiple publishes" do
      expect(fake_connection).to receive(:create_channel).once.and_return(fake_channel)
      5.times { |i| publisher.publish(message: "msg-#{i}") }
    end

    it "returns nil from publish on success" do
      expect(publisher.publish(message: "msg")).to be_nil
    end

    it "returns nil immediately when message is nil" do
      expect(fake_exchange).not_to receive(:publish)
      expect(publisher.publish(message: nil)).to be_nil
    end

    it "passes correlation_id from args into publish options" do
      expect(fake_exchange).to receive(:publish).with("m", hash_including(correlation_id: "explicit"))
      publisher.publish(message: "m", correlation_id: "explicit")
    end

    it "falls back to CorrelationId.current when args has none" do
      EventHub::CorrelationId.current = "from-thread"
      expect(fake_exchange).to receive(:publish).with("m", hash_including(correlation_id: "from-thread"))
      publisher.publish(message: "m")
    end

    it "omits correlation_id from publish options when none is available" do
      expect(fake_exchange).to receive(:publish) do |_msg, opts|
        expect(opts).not_to have_key(:correlation_id)
      end
      publisher.publish(message: "m")
    end

    it "uses provided exchange_name" do
      expect(fake_channel).to receive(:direct).with("custom_x", durable: true).and_return(fake_exchange)
      publisher.publish(message: "m", exchange_name: "custom_x")
    end

    it "drops channel on Bunny::NetworkFailure and reopens on next publish" do
      call_count = 0
      allow(fake_exchange).to receive(:publish) do
        call_count += 1
        raise Bunny::NetworkFailure.new("boom", nil) if call_count == 1
        nil
      end

      expect { publisher.publish(message: "m") }.to raise_error(Bunny::NetworkFailure)
      expect(fake_connection).to receive(:create_channel).and_return(fake_channel)
      publisher.publish(message: "m2")
    end

    it "drops channel on Bunny::ChannelAlreadyClosed and re-raises" do
      allow(fake_exchange).to receive(:publish).and_raise(Bunny::ChannelAlreadyClosed.new("closed", fake_channel))
      expect { publisher.publish(message: "m") }.to raise_error(Bunny::ChannelAlreadyClosed)
    end

    it "tolerates errors when closing the dropped channel" do
      allow(fake_exchange).to receive(:publish).and_raise(Bunny::NetworkFailure.new("boom", nil))
      allow(fake_channel).to receive(:close).and_raise("close failed")
      expect { publisher.publish(message: "m") }.to raise_error(Bunny::NetworkFailure)
    end
  end

  describe "#ensure_channel (retry)" do
    it "retries up to 3 times on transient channel-creation failures" do
      attempts = 0
      allow(fake_connection).to receive(:create_channel) do
        attempts += 1
        raise Bunny::NetworkFailure.new("transient", nil) if attempts < 3
        fake_channel
      end
      allow(publisher).to receive(:sleep)

      expect { publisher.publish(message: "m") }.not_to raise_error
      expect(attempts).to eq(3)
    end

    it "gives up and re-raises after 3 failed attempts" do
      allow(fake_connection).to receive(:create_channel).and_raise(Bunny::NetworkFailure.new("stuck", nil))
      allow(publisher).to receive(:sleep)
      expect { publisher.publish(message: "m") }.to raise_error(Bunny::NetworkFailure)
    end
  end

  describe "#cleanup" do
    it "tolerates exceptions raised by channel#close" do
      publisher.publish(message: "warmup")
      allow(fake_channel).to receive(:close).and_raise(Bunny::ConnectionClosedError.new("torn down"))
      expect { publisher.cleanup }.not_to raise_error
    end

    it "tolerates exceptions raised by connection#close" do
      publisher.publish(message: "warmup")
      allow(fake_connection).to receive(:close).and_raise(Bunny::NetworkFailure.new("torn down", nil))
      expect { publisher.cleanup }.not_to raise_error
    end
  end
end
