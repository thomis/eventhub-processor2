require 'spec_helper'

RSpec.describe EventHub::ActorListener do
  before(:each) do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
  end

  it 'gives a valid actor' do
    expect(@listener).not_to eq(nil)
  end

  it 'handles with_publish' do
    @listener.with_publish(message: 'a message') do |connection, exchange_name, message|
      expect(connection.class).to eq(Bunny::Session)
      expect(exchange_name).to eq('event_hub.inbound')
      expect(message).to eq('a message')
    end
  end

  it 'handles with_publish to different exchange' do
    @listener.with_publish(message: 'a message', exchange_name: 'an_exchange') do |connection, exchange_name, message|
      expect(connection.class).to eq(Bunny::Session)
      expect(exchange_name).to eq('an_exchange')
      expect(message).to eq('a message')
    end
  end

  it 'succeeds to publish message' do
    expect{ @listener.publish(message: EventHub::Message.new.to_json) }.not_to raise_error
  end

  it 'raises exception when restart' do
    expect{ @listener.restart }.to raise_error(RuntimeError, 'Listener is restarting...')
  end

  it 'handles payload' do
    payload = EventHub::Message.new.to_json
    expect{ @listener.handle_payload(payload: payload)}.not_to raise_error
  end

  it 'handles invalid payload' do
    payload = '{]'
    expect{ @listener.handle_payload(payload: payload)}.not_to raise_error
  end
end
