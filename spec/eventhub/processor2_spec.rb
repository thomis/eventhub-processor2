require 'spec_helper'
require 'fileutils'

RSpec.describe EventHub::Processor2 do
  around(:each) do |example|
    Celluloid.boot
    example.run
    Celluloid.shutdown
  end

  it 'has a version number' do
    expect(EventHub::VERSION).not_to be nil
  end

  it 'gets a version' do
    processor = EventHub::Processor2.new
    expect(processor.version).not_to eq(nil)
  end

  it 'get configuration file' do
    processor = EventHub::Processor2.new
    expect(EventHub::Configuration.config_file).to match(/config\/processor2.json$/)
  end

  it 'raises exception if handle_message method is not implemented' do
    p2 = EventHub::Processor2.new
    expect{ p2.handle_message('msg') }.to raise_error(RuntimeError)
  end

  it 'starts and stops' do
    processor = EventHub::Processor2.new
    thr = Thread.new { processor.start }
    sleep 0.5
    processor.stop
    thr.join
    expect(true).to eq(true)
  end

  it 'reloads configuration file' do
    skip "needs refactoring"
    processor = EventHub::Processor2.new
    thr = Thread.new { processor.start }

    # send signal to reload configuration file
    Process.kill 'HUP', 0
    sleep 0.5 # give a bit time to load

    # check value
    expect(EventHub::Configuration.processor[:restart_in_s]).to eq(0)

    processor.stop
    thr.join
    expect(true).to eq(true)
  end


end
