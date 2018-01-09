require 'spec_helper'

RSpec.describe EventHub::ActorListener do

  around(:each) do |example|
    Celluloid.boot
    example.run
    Celluloid.shutdown
  end

  it 'gives a valid actor' do
    # due to rspec caching better to create instance within the test
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    expect(@listener.class).to eq(EventHub::ActorListener)
  end

  it 'handles with_publish' do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    @listener.with_publish(message: 'a message') do |connection, exchange_name, message|
      expect(connection.class).to eq(Bunny::Session)
      expect(exchange_name).to eq('event_hub.inbound')
      expect(message).to eq('a message')
    end
  end

  it 'handles with_publish to different exchange' do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    @listener.with_publish(message: 'a message', exchange_name: 'an_exchange') do |connection, exchange_name, message|
      expect(connection.class).to eq(Bunny::Session)
      expect(exchange_name).to eq('an_exchange')
      expect(message).to eq('a message')
    end
  end

  it 'succeeds to publish message' do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    expect{ @listener.publish(message: EventHub::Message.new.to_json) }.not_to raise_error
  end

  it 'raises exception when restart' do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    expect{ @listener.restart }.to raise_error(RuntimeError, 'Listener is restarting...')
  end

  it 'handles payload' do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    payload = EventHub::Message.new.to_json
    expect{ @listener.handle_payload(payload: payload)}.not_to raise_error
  end

  it 'handles invalid payload' do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    payload = '{]'
    expect{ @listener.handle_payload(payload: payload)}.not_to raise_error
  end
end
