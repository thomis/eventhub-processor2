require "spec_helper"
require "fileutils"

RSpec.describe EventHub::Processor2 do
  around(:each) do |example|
    example.run
  end

  it "has a version number" do
    expect(EventHub::VERSION).not_to be nil
  end

  it "gets a version" do
    processor = EventHub::Processor2.new
    expect(processor.version).not_to eq(nil)
  end

  it "get configuration file" do
    expect(EventHub::Configuration.config_file).to match(/config\/processor2.json$/)
  end

  it "raises exception if handle_message method is not implemented" do
    p2 = EventHub::Processor2.new
    expect { p2.handle_message("msg") }.to raise_error(RuntimeError)
  end

  it "starts and stops" do
    processor = EventHub::Processor2.new
    thr = Thread.new { processor.start }
    sleep 0.5
    processor.stop
    thr.join
    expect(true).to eq(true)
  end
end
