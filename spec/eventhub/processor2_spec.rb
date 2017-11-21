require 'spec_helper'

RSpec.describe Eventhub::Processor2 do
  it 'has a version number' do
    expect(Eventhub::VERSION).not_to be nil
  end

  it 'gets a version' do
    processor = Eventhub::Processor2.new
    expect(processor.version).not_to eq(nil)
  end

  it 'gets an evironment' do
    processor = Eventhub::Processor2.new
    expect(processor.environment).to eq('development')
  end

  it 'gets detached info' do
    processor = Eventhub::Processor2.new
    expect(processor.detached).to eq(false)
  end

  it 'gets a configuration file' do
    processor = Eventhub::Processor2.new
    expect(processor.configuration_file).to match(/processor2.json$/)
  end

  it 'can start and stop' do
    processor = Eventhub::Processor2.new
    thr = Thread.new { processor.start }
    sleep 0.5
    processor.stop
    thr.join
    expect(true).to eq(true)
  end

end
