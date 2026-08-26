require "spec_helper"

RSpec.describe EventHub::Patches::CelluloidLoggerCrash do
  let(:logger_module) { Celluloid::Internals::Logger }
  let(:crash_exception) do
    RuntimeError.new("original").tap { |ex| ex.set_backtrace(caller) }
  end

  it "logs and continues when a registered exception handler itself crashes" do
    saved_handlers = logger_module.instance_variable_get(:@exception_handlers)
    messages = []
    allow(logger_module).to receive(:error) { |m| messages << m.to_s }

    logger_module.instance_variable_set(:@exception_handlers, [proc { raise "handler bug" }])
    expect {
      logger_module.crash("actor crashed", crash_exception)
    }.not_to raise_error

    expect(messages.any? { |m| m.include?("EXCEPTION HANDLER CRASHED") }).to be(true)
  ensure
    logger_module.instance_variable_set(:@exception_handlers, saved_handlers)
  end

  it "does not mutate a frozen input string (the reason the patch exists)" do
    saved_handlers = logger_module.instance_variable_get(:@exception_handlers)
    allow(logger_module).to receive(:error)

    logger_module.instance_variable_set(:@exception_handlers, [])
    frozen = "frozen crash message"
    expect {
      logger_module.crash(frozen, crash_exception)
    }.not_to raise_error
  ensure
    logger_module.instance_variable_set(:@exception_handlers, saved_handlers)
  end
end
