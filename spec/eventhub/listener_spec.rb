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
    expect(@listener).not_to eq(nil)
  end

  it 'succeeds to publish message' do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    expect{ @listener.publish(message: EventHub::Message.new.to_json) }.not_to raise_error
  end

  it 'succeeds to publish message to different exchange' do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    expect{ @listener.publish(message: EventHub::Message.new.to_json, exchange_name: 'an_exchange') }.not_to raise_error
  end

  it 'raises exception when restart' do
    @listener = EventHub::ActorListener.new(EventHub::Processor2.new)
    expect(@listener).not_to eq(nil)
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
