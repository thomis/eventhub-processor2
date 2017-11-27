require 'spec_helper'

RSpec.describe Eventhub::Configuration do
  it 'loads defaults' do
    Eventhub::Configuration.load!
    expect(Eventhub::Configuration.server[:user]).to eq('guest')
    expect(Eventhub::Configuration.server[:password]).to eq('guest')
    expect(Eventhub::Configuration.server[:host]).to eq('localhost')
    expect(Eventhub::Configuration.server[:vhost]).to eq('eventhub')
    expect(Eventhub::Configuration.server[:port]).to eq(5672)
    expect(Eventhub::Configuration.server[:ssl]).to eq(false)
    expect(Eventhub::Configuration.processor[:heartbeat_cycle_in_s]).to eq(300)
    expect(Eventhub::Configuration.processor[:watchdog_cycle_in_s]).to eq(15)
    expect(Eventhub::Configuration.processor[:listener_queues]).to eq(['undefined'])
  end

  it 'loads default environment configuration from file' do
    Eventhub::Configuration.load!('spec/fixtures/development.json')
    expect(Eventhub::Configuration.server[:user]).to eq('guest_development')
    expect(Eventhub::Configuration.server[:password]).to eq('guest_development')
    expect(Eventhub::Configuration.server[:host]).to eq('localhost_development')
    expect(Eventhub::Configuration.server[:vhost]).to eq('eventhub_development')
    expect(Eventhub::Configuration.server[:port]).to eq(5673)
    expect(Eventhub::Configuration.server[:ssl]).to eq(true)
    expect(Eventhub::Configuration.processor[:heartbeat_cycle_in_s]).to eq(400)
    expect(Eventhub::Configuration.processor[:watchdog_cycle_in_s]).to eq(60)
    expect(Eventhub::Configuration.processor[:listener_queues]).to eq(['demo'])
  end

  it 'loads test environment configuration from file' do
    Eventhub::Configuration.load!('spec/fixtures/test.json', environment: 'test')
    expect(Eventhub::Configuration.server[:user]).to eq('guest_test')
    expect(Eventhub::Configuration.server[:password]).to eq('guest_test')
    expect(Eventhub::Configuration.server[:host]).to eq('localhost_test')
    expect(Eventhub::Configuration.server[:vhost]).to eq('eventhub_test')
    expect(Eventhub::Configuration.server[:port]).to eq(5674)
    expect(Eventhub::Configuration.server[:ssl]).to eq(true)
    expect(Eventhub::Configuration.processor[:heartbeat_cycle_in_s]).to eq(401)
    expect(Eventhub::Configuration.processor[:watchdog_cycle_in_s]).to eq(61)
    expect(Eventhub::Configuration.processor[:listener_queues]).to eq(['demo'])
  end

  it 'read additional values' do
    Eventhub::Configuration.load!('spec/fixtures/test.json', environment: 'test')
    expect(Eventhub::Configuration.value_name1).to eq('value1')
    expect(Eventhub::Configuration.value_name2[:value_name3]).to eq('value3')
  end

  it 'fails read an unknown value' do
    Eventhub::Configuration.load!
    expect {
      Eventhub::Configuration.unknown
    }.to raise_error(NoMethodError, 'unknown configuration [unknown]')
  end

  it 'allows to read from configuration file multiple times' do
    Eventhub::Configuration.load!
    expect(Eventhub::Configuration.server[:user]).to eq('guest')
    Eventhub::Configuration.load!('spec/fixtures/development.json')
    expect(Eventhub::Configuration.server[:user]).to eq('guest_development')
  end
end
