require 'spec_helper'

RSpec.describe EventHub::BaseException do
  it 'raises an exception' do
    expect{ raise EventHub::BaseException}.to raise_error(EventHub::BaseException)
  end

  it 'raises an exception' do
    expect{ raise EventHub::BaseException.new}.to raise_error(EventHub::BaseException)
  end

  it 'raises an exception' do
    error = EventHub::BaseException.new
    expect(error.message).to eq(nil)
    expect(error.code).to eq(EventHub::STATUS_DEADLETTER)
    expect{raise error}.to raise_error(EventHub::BaseException)
  end

  it 'raises an exception with message' do
    error = EventHub::BaseException.new('booom')
    expect(error.message).to eq('booom')
    expect(error.code).to eq(EventHub::STATUS_DEADLETTER)
    expect{raise error}.to raise_error(EventHub::BaseException)
  end

  it 'raises an exception with message and code' do
    error = EventHub::BaseException.new('booom', EventHub::STATUS_RETRY)
    expect(error.message).to eq('booom')
    expect(error.code).to eq(EventHub::STATUS_RETRY)
    expect{raise error}.to raise_error(EventHub::BaseException)
  end
end
