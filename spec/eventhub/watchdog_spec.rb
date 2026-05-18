require "spec_helper"

RSpec.describe EventHub::ActorWatchdog do
  before(:all) do
    EventHub::Configuration.load!
  end

  let(:fake_connection) do
    c = instance_double(Bunny::Session)
    allow(c).to receive(:start)
    allow(c).to receive(:close)
    c
  end

  let(:watchdog) do
    # bypass async.start
    wd = EventHub::ActorWatchdog.allocate
    wd.instance_variable_set(:@consecutive_failures, 0)
    allow(wd).to receive(:create_bunny_connection).and_return(fake_connection)
    wd
  end

  describe "#watch (private)" do
    it "resets the failure counter when all queues exist" do
      allow(fake_connection).to receive(:queue_exists?).and_return(true)
      watchdog.instance_variable_set(:@consecutive_failures, 2)
      watchdog.send(:watch)
      expect(watchdog.instance_variable_get(:@consecutive_failures)).to eq(0)
    end

    it "increments the counter but does not raise on first missing queue" do
      allow(fake_connection).to receive(:queue_exists?).and_return(false)
      expect { watchdog.send(:watch) }.not_to raise_error
      expect(watchdog.instance_variable_get(:@consecutive_failures)).to eq(1)
    end

    it "raises only after MISSING_QUEUE_THRESHOLD consecutive failures" do
      allow(fake_connection).to receive(:queue_exists?).and_return(false)
      threshold = EventHub::ActorWatchdog::MISSING_QUEUE_THRESHOLD
      (threshold - 1).times { watchdog.send(:watch) }
      expect { watchdog.send(:watch) }.to raise_error(/Queue\(s\) missing for #{threshold} consecutive cycles/)
    end

    it "swallows Bunny::NetworkFailure as a transient broker error" do
      allow(fake_connection).to receive(:start).and_raise(Bunny::NetworkFailure.new("flapping", nil))
      expect { watchdog.send(:watch) }.not_to raise_error
    end

    it "swallows Bunny::TCPConnectionFailed as a transient broker error" do
      allow(fake_connection).to receive(:start).and_raise(Bunny::TCPConnectionFailed.new("refused", "localhost", 5672))
      expect { watchdog.send(:watch) }.not_to raise_error
    end

    it "swallows Timeout::Error as a transient broker error" do
      allow(fake_connection).to receive(:start).and_raise(Timeout::Error.new("timed out"))
      expect { watchdog.send(:watch) }.not_to raise_error
    end

    it "tolerates exceptions raised when closing the connection in ensure" do
      allow(fake_connection).to receive(:queue_exists?).and_return(true)
      allow(fake_connection).to receive(:close).and_raise("close failed")
      expect { watchdog.send(:watch) }.not_to raise_error
    end
  end

  describe "#cleanup" do
    it "logs without raising" do
      expect { watchdog.cleanup }.not_to raise_error
    end
  end
end
