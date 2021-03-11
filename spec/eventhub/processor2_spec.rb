require "spec_helper"
require "fileutils"

RSpec.describe EventHub::Processor2 do
  before(:all) do
    Support.ensure_rabbitmq_is_available
  end

  let!(:processor) {
    EventHub::Processor2.new
  }

  it "has a version number" do
    expect(EventHub::VERSION).not_to be nil
  end

  it "gets a version" do
    expect(processor.version).not_to eq(nil)
  end

  it "get configuration file" do
    expect(EventHub::Configuration.config_file).to match(/config\/processor2.json$/)
  end

  it "raises exception if handle_message method is not implemented" do
    expect { processor.handle_message("msg") }.to raise_error(RuntimeError)
  end

  it "starts and stops" do
    thr = Thread.new { processor.start }
    sleep 0.5
    processor.stop
    thr.join
    expect(true).to eq(true)
  end
end
