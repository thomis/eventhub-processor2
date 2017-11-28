require 'spec_helper'

RSpec.describe Eventhub::Processor2 do
  it 'has a version number' do
    expect(Eventhub::VERSION).not_to be nil
  end

  it 'gets a version' do
    processor = Eventhub::Processor2.new
    expect(processor.version).not_to eq(nil)
  end

  it 'get configuration file' do
    processor = Eventhub::Processor2.new
    expect(Eventhub::Configuration.config_file).to match(/config\/processor2.json$/)

  end

  it 'starts and stops' do
    processor = Eventhub::Processor2.new
    thr = Thread.new { processor.start }
    sleep 0.5
    processor.stop
    thr.join
    expect(true).to eq(true)
  end

end
