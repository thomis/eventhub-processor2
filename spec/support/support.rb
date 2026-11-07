module Support
  # Give up after this many attempts (one per second) instead of waiting
  # forever and running into the 6h GitHub Actions job limit.
  MAX_RABBITMQ_WAIT_ATTEMPTS = 120

  def self.ensure_rabbitmq_is_available(max_attempts: MAX_RABBITMQ_WAIT_ATTEMPTS)
    attempts = 0
    begin
      Bunny.new(vhost: "event_hub", user: "guest", password: "guest").start
    rescue => e
      attempts += 1
      raise "RabbitMQ not available after #{attempts} attempts: #{e.message}" if attempts >= max_attempts

      puts "Waiting for rabbitmq to be available..."
      sleep 1
      retry
    end
  end
end
