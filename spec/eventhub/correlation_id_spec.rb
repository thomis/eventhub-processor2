require "spec_helper"

RSpec.describe EventHub::ExecutionId do
  after(:each) do
    described_class.clear
  end

  describe ".current" do
    it "returns nil when not set" do
      expect(described_class.current).to be_nil
    end

    it "returns the set value" do
      described_class.current = "exec-123"
      expect(described_class.current).to eq("exec-123")
    end
  end

  describe ".current=" do
    it "sets the execution_id" do
      described_class.current = "exec-456"
      expect(described_class.current).to eq("exec-456")
    end
  end

  describe ".clear" do
    it "clears the execution_id" do
      described_class.current = "to-be-cleared"
      described_class.clear
      expect(described_class.current).to be_nil
    end
  end
end

RSpec.describe EventHub::CorrelationId do
  after(:each) do
    described_class.clear
  end

  describe ".current" do
    it "returns nil when not set" do
      expect(described_class.current).to be_nil
    end

    it "returns the set value" do
      described_class.current = "test-123"
      expect(described_class.current).to eq("test-123")
    end
  end

  describe ".current=" do
    it "sets the correlation_id" do
      described_class.current = "abc-456"
      expect(described_class.current).to eq("abc-456")
    end
  end

  describe ".clear" do
    it "clears the correlation_id" do
      described_class.current = "to-be-cleared"
      described_class.clear
      expect(described_class.current).to be_nil
    end
  end

  describe ".with" do
    it "sets correlation_id within block and clears after" do
      described_class.with("block-123") do
        expect(described_class.current).to eq("block-123")
      end
      expect(described_class.current).to be_nil
    end

    it "restores previous value after block" do
      described_class.current = "outer"
      described_class.with("inner") do
        expect(described_class.current).to eq("inner")
      end
      expect(described_class.current).to eq("outer")
    end

    it "yields without setting if correlation_id is nil" do
      described_class.current = "existing"
      described_class.with(nil) do
        expect(described_class.current).to eq("existing")
      end
      expect(described_class.current).to eq("existing")
    end

    it "yields without setting if correlation_id is empty string" do
      described_class.current = "existing"
      described_class.with("") do
        expect(described_class.current).to eq("existing")
      end
      expect(described_class.current).to eq("existing")
    end

    it "clears correlation_id even if block raises" do
      expect {
        described_class.with("error-case") do
          raise "test error"
        end
      }.to raise_error("test error")
      expect(described_class.current).to be_nil
    end
  end
end

RSpec.describe EventHub::LoggerProxy do
  let(:mock_logger) { double("logger") }
  let(:proxy) { described_class.new(mock_logger) }

  after(:each) do
    EventHub::CorrelationId.clear
    EventHub::ExecutionId.clear
  end

  describe "log methods" do
    %i[debug info warn error fatal unknown].each do |level|
      describe "##{level}" do
        it "passes message without ids when not set" do
          expect(mock_logger).to receive(level).with("test message")
          proxy.send(level, "test message")
        end

        it "includes correlation_id as separate field when set" do
          EventHub::CorrelationId.current = "corr-123"
          expect(mock_logger).to receive(level).with({message: "test message", correlation_id: "corr-123"})
          proxy.send(level, "test message")
        end

        it "includes execution_id as separate field when set" do
          EventHub::ExecutionId.current = "exec-456"
          expect(mock_logger).to receive(level).with({message: "test message", execution_id: "exec-456"})
          proxy.send(level, "test message")
        end

        it "includes both correlation_id and execution_id when both set" do
          EventHub::CorrelationId.current = "corr-123"
          EventHub::ExecutionId.current = "exec-456"
          expect(mock_logger).to receive(level).with({message: "test message", correlation_id: "corr-123", execution_id: "exec-456"})
          proxy.send(level, "test message")
        end

        it "supports block form" do
          expect(mock_logger).to receive(level).with("block message")
          proxy.send(level) { "block message" }
        end

        it "includes correlation_id as separate field with block form" do
          EventHub::CorrelationId.current = "block-corr"
          expect(mock_logger).to receive(level).with({message: "block message", correlation_id: "block-corr"})
          proxy.send(level) { "block message" }
        end
      end
    end
  end

  describe "#method_missing" do
    it "delegates unknown methods to wrapped logger" do
      expect(mock_logger).to receive(:some_method).with("arg1", "arg2")
      proxy.some_method("arg1", "arg2")
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for methods the wrapped logger responds to" do
      allow(mock_logger).to receive(:respond_to?).with(:custom_method, false).and_return(true)
      expect(proxy.respond_to?(:custom_method)).to be true
    end

    it "returns false for methods the wrapped logger does not respond to" do
      allow(mock_logger).to receive(:respond_to?).with(:unknown_method, false).and_return(false)
      expect(proxy.respond_to?(:unknown_method)).to be false
    end
  end
end
