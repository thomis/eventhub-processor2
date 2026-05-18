require "spec_helper"

RSpec.describe "EventHub.format_celluloid_exception" do
  before(:all) do
    EventHub::Configuration.load!
  end

  it "returns a message without a prefix when no actor is current" do
    formatted = EventHub.format_celluloid_exception(RuntimeError.new("boom"))
    expect(formatted).to eq("Exception occured: RuntimeError: boom")
  end

  it "includes the actor class name when invoked from inside an actor" do
    klass = Class.new do
      include Celluloid

      def trigger
        EventHub.format_celluloid_exception(RuntimeError.new("inside-actor"))
      end
    end
    stub_const("EventHub::TestExceptionActor", klass)

    actor = klass.new
    formatted = actor.trigger
    expect(formatted).to include("[EventHub::TestExceptionActor]")
    expect(formatted).to include("RuntimeError: inside-actor")
    actor.terminate
  end

  it "returns an unprefixed message if introspection of the actor itself raises" do
    allow(Celluloid).to receive(:actor?).and_raise("introspection broken")
    formatted = EventHub.format_celluloid_exception(StandardError.new("oops"))
    expect(formatted).to eq("Exception occured: StandardError: oops")
  end
end
