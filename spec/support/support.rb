module Support
  def self.ensure_rabbitmq_is_available
    Bunny.new(vhost: "event_hub", user: "guest", password: "guest").start
  rescue
    puts "Waiting for rabbitmq to be available..."
    sleep 1
    retry
  end
end
