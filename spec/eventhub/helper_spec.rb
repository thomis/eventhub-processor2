require "spec_helper"

class EventHub::Test
end

class EventHub::Test::Test
end

class EventHub::Test::TestClass
end

module Test
  class Test
  end
end

RSpec.describe EventHub::Helper do
  include EventHub::Helper

  context "name from class" do
    it "gets class name" do
      a_class = EventHub::Test.new
      expect(get_name_from_class(a_class)).to eq("test")
    end

    it "gets class name 2" do
      a_class = EventHub::Test::Test.new
      expect(get_name_from_class(a_class)).to eq("test.test")
    end

    it "gets class name with camel case name" do
      a_class = EventHub::Test::TestClass.new
      expect(get_name_from_class(a_class)).to eq("test.test_class")
    end

    it "get class name without eventhub module" do
      a_class = Test::Test.new
      expect(get_name_from_class(a_class)).to eq("test.test")
    end
  end

  context "stamp" do
    it "give actual time in UTC format" do
      expect(now_stamp).to match(/^\d{4,4}-\d{2,2}-\d{2,2}T\d{2,2}:\d{2,2}:\d{2,2}.\d{5,6}Z/)
    end

    it "gives given time in UTC format" do
      time = Time.utc(2017, 1, 2, 3, 4, 5.123456)
      expect(now_stamp(time)).to match(/^2017-01-02T03:04:05.123456Z/)
    end
  end

  context "bunny_connection_properties" do
    it "returns hash" do
      EventHub::Configuration.load!
      connection = create_bunny_connection
      expect(connection.class).to eq(Bunny::Session)
    end

    it "enables Bunny network auto-recovery in connection options" do
      EventHub::Configuration.load!
      _url, props = bunny_connection_options
      expect(props[:automatically_recover]).to eq(true)
      expect(props[:network_recovery_interval]).to eq(5)
      expect(props[:recovery_attempts]).to be_nil
      expect(props[:continuation_timeout]).to eq(15_000)
      expect(props[:recovery_attempts_exhausted]).to be_a(Proc)
    end

    it "recovery_attempts_exhausted callback logs and attempts an actor restart" do
      EventHub::Configuration.load!
      _url, props = bunny_connection_options

      fake_listener = double("listener")
      fake_async = double("async")
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp).and_return(fake_listener)
      allow(fake_listener).to receive(:async).and_return(fake_async)
      expect(fake_async).to receive(:restart)
      expect(EventHub.logger).to receive(:error).with(/recovery attempts exhausted/)
      props[:recovery_attempts_exhausted].call
    end

    it "recovery_attempts_exhausted callback is a no-op if listener actor is absent" do
      EventHub::Configuration.load!
      _url, props = bunny_connection_options
      allow(Celluloid::Actor).to receive(:[]).with(:actor_listener_amqp).and_return(nil)
      expect(EventHub.logger).to receive(:error).with(/recovery attempts exhausted/)
      expect { props[:recovery_attempts_exhausted].call }.not_to raise_error
    end
  end
end
