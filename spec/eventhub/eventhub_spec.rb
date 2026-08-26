RSpec.describe EventHub::Processor2 do
  let(:sleeper) { instance_double(EventHub::Sleeper, start: nil, stop: nil) }
  let(:statistics) { instance_double(EventHub::Statistics) }
  let(:logger) { instance_double(Logger) }

  before do
    allow(EventHub::Configuration).to receive(:name=)
    allow(EventHub::Configuration).to receive(:parse_options)
    allow(EventHub::Configuration).to receive(:load!)
    allow(EventHub::Sleeper).to receive(:new).and_return(sleeper)
    allow(EventHub::Statistics).to receive(:new).and_return(statistics)
    allow(EventHub).to receive(:logger).and_return(logger)
    allow(logger).to receive(:info)
    allow(logger).to receive(:error)
  end

  describe "#initialize" do
    it "sets up processor with default values" do
      processor = described_class.new(name: "TestProcessor")

      expect(EventHub::Configuration).to have_received(:name=).with("TestProcessor")
      expect(EventHub::Configuration).to have_received(:parse_options)
      expect(EventHub::Configuration).to have_received(:load!)
      expect(processor.started_at).to be_a(Time)
      expect(processor.statistics).to eq(statistics)
    end
  end

  describe "#start" do
    it "logs start and stop messages" do
      processor = described_class.new
      allow(processor).to receive(:before_start)
      allow(processor).to receive(:main_event_loop)
      allow(processor).to receive(:after_stop)

      processor.start

      expect(logger).to have_received(:info).with(/has been started/)
      expect(logger).to have_received(:info).with(/has been stopped/)
    end

    it "logs an error if an exception occurs" do
      processor = described_class.new
      allow(processor).to receive(:main_event_loop).and_raise("Test Error")

      expect { processor.start }.not_to raise_error
      expect(logger).to have_received(:error).with(/Unexpected error in Processor2.start/)
    end
  end

  describe "#stop" do
    it "adds :TERM to the command queue" do
      processor = described_class.new
      processor.stop
      expect(processor.instance_variable_get(:@command_queue)).to include(:TERM)
    end
  end

  describe "#handle_message" do
    it "raises an error when not implemented" do
      processor = described_class.new
      expect { processor.handle_message(nil) }.to raise_error("need to be implemented in derived class")
    end
  end

  describe "#setup_signal_handler" do
    it "traps signals and adds them to the command queue" do
      processor = described_class.new
      allow(Signal).to receive(:trap).and_yield

      processor.send(:setup_signal_handler)

      EventHub::Processor2::ALL_SIGNALS.each do |signal|
        expect(Signal).to have_received(:trap).with(signal)
      end
    end
  end

  describe "#main_event_loop" do
    let(:processor) { described_class.new }

    before do
      allow(Celluloid).to receive(:boot)
      allow(Celluloid).to receive(:shutdown)
      allow(Celluloid).to receive(:running?).and_return(false)
      allow(processor).to receive(:setup_signal_handler)
      allow(processor).to receive(:start_supervisor)
    end

    it "reloads configuration on HUP and restarts a known listener actor" do
      fake_async = double("async", restart: nil)
      listener = double("listener", async: fake_async)
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp).and_return(listener)

      # Array#pop takes from the end: :HUP is processed first, :TERM ends the loop
      processor.instance_variable_get(:@command_queue).push(:TERM, :HUP)
      processor.send(:main_event_loop)

      expect(EventHub::Configuration).to have_received(:load!).at_least(:once)
      expect(fake_async).to have_received(:restart)
    end

    it "logs when no listener actor is available after a HUP reload" do
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp).and_return(nil)

      processor.instance_variable_get(:@command_queue).push(:TERM, :HUP)
      processor.send(:main_event_loop)

      expect(logger).to have_received(:info).with(/unable to get a valid listener actor/)
    end

    it "waits until Celluloid has fully stopped after shutdown" do
      allow(Celluloid).to receive(:running?).and_return(true, false)

      processor.instance_variable_get(:@command_queue).push(:TERM)
      processor.send(:main_event_loop)

      expect(Celluloid).to have_received(:running?).twice
    end
  end

  describe "#start_supervisor" do
    it "injects a before_restart hook that logs and starts the sleeper" do
      captured = nil
      fake_config = double("supervision config", deploy: nil)
      allow(fake_config).to receive(:injection!) { |_name, blk| captured = blk }
      allow(Celluloid::Supervision::Configuration).to receive(:define).and_return(fake_config)

      processor = described_class.new
      processor.send(:start_supervisor)

      expect(fake_config).to have_received(:deploy)
      expect(captured).to be_a(Proc)

      captured.call
      expect(sleeper).to have_received(:start)
      expect(logger).to have_received(:info).with(/Restarting in .* seconds/)
    end
  end

  describe "#publish" do
    let(:processor) { described_class.new }
    let(:actor) { instance_double("Actor", publish: nil) }

    before do
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp).and_return(actor)
      allow(EventHub.logger).to receive(:error)
    end

    it "publishes a message using the actor" do
      args = {key: "value"}
      processor.publish(args)

      expect(actor).to have_received(:publish).with(args)
    end

    it "logs and raises an error if publish fails" do
      allow(actor).to receive(:publish).and_raise(StandardError.new("Publish failed"))

      expect { processor.publish(key: "value") }.to raise_error(StandardError, "Publish failed")
      expect(EventHub.logger).to have_received(:error).with(/Unexpected exeption while publish/)
    end
  end
end
