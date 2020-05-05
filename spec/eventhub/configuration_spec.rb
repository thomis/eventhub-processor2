require 'spec_helper'

RSpec.describe EventHub::Configuration do

  before(:each) do
    EventHub::Configuration.reset
  end

  context 'argument options' do
    it 'parses no options' do
      EventHub::Configuration.parse_options()
      expect(EventHub::Configuration.environment).to eq('development')
      expect(EventHub::Configuration.detached).to eq(false)
    end

    it 'parses environment' do
      EventHub::Configuration.parse_options(['-e', 'integration'])
      expect(EventHub::Configuration.environment).to eq('integration')
    end

    it 'parses detached' do
      EventHub::Configuration.parse_options(['-d'])
      expect(EventHub::Configuration.detached).to eq(true)
    end

    it 'parses environment and detached' do
      EventHub::Configuration.parse_options(['-d', '-e', 'integration'])
      expect(EventHub::Configuration.environment).to eq('integration')
      expect(EventHub::Configuration.detached).to eq(true)
    end

    it 'parses unknown option' do
      success = EventHub::Configuration.parse_options(['-k'])
      expect(success).to eq(false)
    end

    it 'parses option without value' do
      success = EventHub::Configuration.parse_options(['-c'])
      expect(success).to eq(false)
    end

    it 'parses configuration file' do
      success = EventHub::Configuration.parse_options(['-c', 'a_configuration_file'])
      expect(success).to eq(true)
      expect(EventHub::Configuration.config_file).to eq('a_configuration_file')
    end
  end

  context 'configuration file' do
    it 'gets default evironment' do
      expect(EventHub::Configuration.environment).to eq('development')
    end

    it 'gets default detached info' do
      expect(EventHub::Configuration.detached).to eq(false)
    end

    it 'get default configuration file' do
      expect(EventHub::Configuration.config_file).to match(/undefined.json$/)
    end

    it 'loads defaults' do
      EventHub::Configuration.load!
      expect(EventHub::Configuration.server[:user]).to eq('guest')
      expect(EventHub::Configuration.server[:password]).to eq('guest')
      expect(EventHub::Configuration.server[:host]).to eq('localhost')
      expect(EventHub::Configuration.server[:vhost]).to eq('event_hub')
      expect(EventHub::Configuration.server[:port]).to eq(5672)
      expect(EventHub::Configuration.server[:tls]).to eq(false)
      expect(EventHub::Configuration.processor[:heartbeat_cycle_in_s]).to eq(300)
      expect(EventHub::Configuration.processor[:watchdog_cycle_in_s]).to eq(60)
      expect(EventHub::Configuration.processor[:listener_queues]).to eq(['undefined'])
    end

    it 'loads default environment configuration from file' do
      EventHub::Configuration.load!(config_file: 'spec/fixtures/development.json')
      expect(EventHub::Configuration.server[:user]).to eq('guest_development')
      expect(EventHub::Configuration.server[:password]).to eq('guest_development')
      expect(EventHub::Configuration.server[:host]).to eq('localhost_development')
      expect(EventHub::Configuration.server[:vhost]).to eq('eventhub_development')
      expect(EventHub::Configuration.server[:port]).to eq(5673)
      expect(EventHub::Configuration.server[:tls]).to eq(true)
      expect(EventHub::Configuration.processor[:heartbeat_cycle_in_s]).to eq(400)
      expect(EventHub::Configuration.processor[:watchdog_cycle_in_s]).to eq(60)
      expect(EventHub::Configuration.processor[:listener_queues]).to eq(['demo'])
    end

    it 'loads test environment configuration from file' do
      EventHub::Configuration.load!(config_file: 'spec/fixtures/test.json', environment: 'test')
      expect(EventHub::Configuration.server[:user]).to eq('guest_test')
      expect(EventHub::Configuration.server[:password]).to eq('guest_test')
      expect(EventHub::Configuration.server[:host]).to eq('localhost_test')
      expect(EventHub::Configuration.server[:vhost]).to eq('eventhub_test')
      expect(EventHub::Configuration.server[:port]).to eq(5674)
      expect(EventHub::Configuration.server[:tls]).to eq(true)
      expect(EventHub::Configuration.processor[:heartbeat_cycle_in_s]).to eq(401)
      expect(EventHub::Configuration.processor[:watchdog_cycle_in_s]).to eq(61)
      expect(EventHub::Configuration.processor[:listener_queues]).to eq(['demo'])
    end

    it 'read additional values' do
      EventHub::Configuration.load!(config_file: 'spec/fixtures/test.json', environment: 'test')
      expect(EventHub::Configuration.value_name1).to eq('value1')
      expect(EventHub::Configuration.value_name2[:value_name3]).to eq('value3')
    end

    it 'fails read an unknown value' do
      EventHub::Configuration.load!
      expect {
        EventHub::Configuration.unknown
      }.to raise_error(NoMethodError, 'unknown configuration [unknown]')
    end

    it 'allows to read from configuration file multiple times' do
      EventHub::Configuration.load!(environment: 'development')
      expect(EventHub::Configuration.server[:user]).to eq('guest')
      EventHub::Configuration.load!(config_file: 'spec/fixtures/development.json')
      expect(EventHub::Configuration.server[:user]).to eq('guest_development')
    end
  end

  context 'deprecated method' do
    it 'returns configuration instance' do
      expect(EventHub::Configuration.instance).to eq(EventHub::Configuration)
    end

    it 'returns configuration data' do
      expect(EventHub::Configuration.instance.data.class).to eq(Hash)
    end

    it 'returns configuration keys as strings' do
      EventHub::Configuration.load!(config_file: 'spec/fixtures/development_stringify.json')
      data = EventHub::Configuration.instance.data

      expect(data['a']).to eq('b')
      expect(data['c']['d']).to eq('e')
      expect(data['f'][0]['g']).to eq('h')
      expect(data['f'][1]['i']['k']).to eq('l')
    end
  end
end
