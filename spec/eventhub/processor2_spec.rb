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

  it 'starts and stops' do
    processor = EventHub::Processor2.new
    thr = Thread.new { processor.start }
    sleep 0.5
    processor.stop
    thr.join
    expect(true).to eq(true)
  end

  it 'reloads configuration file' do
    config_file_content = '{ "development": { "processor": { "heartbeat_cycle_in_s": 60 }}}'

    processor = EventHub::Processor2.new
    thr = Thread.new { processor.start }
    sleep 0.5

    # write new configuration file
    FileUtils.mkdir_p('./config')
    IO.write('./config/processor2.json', config_file_content)

    # send signal to reload configuration file
    Process.kill 'HUP', 0
    sleep 1

    # check value again
    expect(EventHub::Configuration.processor[:heartbeat_cycle_in_s]).to eq(60)

    sleep 1
    processor.stop
    thr.join
    expect(true).to eq(true)

    # remove config folder with files
    FileUtils.rm('./config/processor2.json')
    FileUtils.rmdir('./config')
  end


end
