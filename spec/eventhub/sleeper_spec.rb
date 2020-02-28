require 'spec_helper'

RSpec.describe EventHub::Message do
  it 'sleeps for given time' do
    start = Time.now
    EventHub::Sleeper.new.start(2)
    stop = Time.now
    expect(((stop - start) - 2) < 0.01).to eq(true), "Expected to wait for 2 seconds but was waiting #{stop-start} seconds"
  end

  it 'allows to interrupt an initialize sleep' do
    slp = EventHub::Sleeper.new
    expect{ slp.stop}.not_to raise_error
  end

  it 'stops a running sleep' do
    threads = []
    slp = EventHub::Sleeper.new

    # thread with interruptable sleep
    start = Time.now
    threads << Thread.new do
      slp.start(5)
    end

    # thread which interrupts the sleep
    threads << Thread.new do
      sleep 2
      slp.stop
    end

    # wait for both threads to finish
    threads.each { |thr| thr.join }
    stop = Time.now

    expect(((stop - start) - 2) < 0.01).to eq(true), "Expected to wait for 2 seconds but was waiting #{stop-start} seconds"
  end

  it 'interrupts a sleep multiple times' do
    threads = []
    slp = EventHub::Sleeper.new

    # thread with interruptable sleep
    start = Time.now
    threads << Thread.new do
      slp.start(5)
    end

    # thread which interrupts the sleep
    threads << Thread.new do
      sleep 2
      slp.stop
      slp.stop
    end

    # wait for both threads to finish
    threads.each { |thr| thr.join }
    stop = Time.now

    expect(((stop - start) - 2) < 0.01).to eq(true), "Expected to wait for 2 seconds but was waiting #{stop-start} seconds"
  end
end
