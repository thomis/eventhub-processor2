require "spec_helper"

RSpec.describe EventHub::ActorListenerHttp do
  before(:all) do
    Support.ensure_rabbitmq_is_available
  end

  let!(:listener) {
    EventHub::ActorListenerHttp.new
  }

  it "gives a valid actor" do
    # due to rspec caching better to create instance within the test
    expect(listener).not_to eq(nil)
  end

  it "succeeds to call rest endpoint" do
    # expect { listener.publish(message: EventHub::Message.new.to_json) }.not_to raise_error
  end
end
