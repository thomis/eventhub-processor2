require "spec_helper"

RSpec.describe "EventHub.logger" do
  before(:all) do
    EventHub::Configuration.load!
  end

  it "builds a console-only logger when console_log_only is set" do
    saved = EventHub.instance_variable_get(:@logger)
    EventHub.remove_instance_variable(:@logger) if EventHub.instance_variable_defined?(:@logger)
    allow(EventHub::Configuration).to receive(:console_log_only).and_return(true)

    logger = EventHub.logger

    expect(logger).to be_a(EventHub::LoggerProxy)
  ensure
    EventHub.instance_variable_set(:@logger, saved)
  end
end
