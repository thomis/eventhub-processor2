require "spec_helper"

# Performance baseline. Excluded from `rake spec` via `--tag ~performance`.
# Run with: `bundle exec rake test:performance`
# Override floor with: `PERF_FLOOR=750 bundle exec rake test:performance`
RSpec.describe "ActorPublisher throughput baseline", :performance do
  before(:all) do
    Support.ensure_rabbitmq_is_available
    EventHub::Configuration.load!
  end

  # Measured baseline on local Mac -> local RabbitMQ container: ~7,300 msg/s
  # with very low variance (~3% spread across runs). A 5,000 msg/s floor gives
  # ~30% headroom over the slowest observation — tight enough to catch real
  # regressions (channel-per-publish drops throughput 5-10x), loose enough to
  # absorb normal variance. Override with PERF_FLOOR for slower environments.
  floor = Integer(ENV.fetch("PERF_FLOOR", "5000"))
  messages = Integer(ENV.fetch("PERF_MESSAGES", "2000"))
  warmup = Integer(ENV.fetch("PERF_WARMUP", "100"))
  payload_bytes = Integer(ENV.fetch("PERF_PAYLOAD_BYTES", "512"))

  it "publishes at least #{floor} msg/s on a reused channel" do
    publisher = EventHub::ActorPublisher.new
    payload = "x" * payload_bytes

    begin
      # Warm up: open channel, declare exchange, prime confirm tracking.
      warmup.times { publisher.publish(message: payload) }

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      messages.times { publisher.publish(message: payload) }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      rate = messages / elapsed
      puts format(
        "\n  [perf] %d msgs of %d bytes in %.3fs => %.1f msg/s (floor=%d)",
        messages, payload_bytes, elapsed, rate, floor
      )
      expect(rate).to be >= floor
    ensure
      publisher.terminate if publisher.alive?
    end
  end
end
