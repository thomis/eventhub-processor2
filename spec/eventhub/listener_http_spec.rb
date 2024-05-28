require "spec_helper"
require "uri"
require "net/http"

RSpec.describe EventHub::ActorListenerHttp do
  before(:all) do
    Support.ensure_rabbitmq_is_available
  end

  let(:listener) {
    EventHub::ActorListenerHttp.new(port: 8081)
  }

  it "gives a valid actor" do
    # due to rspec caching better to create instance within the test
    expect(listener).not_to eq(nil)
  end

  it "succeeds to call rest endpoint" do
    sleep 0.2
    uri = URI("http://localhost:8081/svc/processor2/heartbeat")
    res = Net::HTTP.get_response(uri)

    expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
    expect(res.body).to eq("OK")
  end

  it "fails with not found" do
    sleep 0.1
    uri = URI("http://localhost:8081/unknown")
    res = Net::HTTP.post(uri, nil)

    expect(res.is_a?(Net::HTTPNotFound)).to eq(true)
    expect(res.body).to match(/Not Found/)
  end

  it "fails with method not allowed" do
    sleep 0.1
    uri = URI("http://localhost:8081/svc/processor2/heartbeat")
    res = Net::HTTP.post(uri, nil)

    expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
    expect(res.body).to eq("Method Not Allowed")
  end
end
