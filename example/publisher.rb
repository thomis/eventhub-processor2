require 'bunny'
require 'celluloid/current'
require 'json'
require 'securerandom'

Celluloid.logger = nil
Celluloid.exception_handler { |ex| puts "Exception occured: #{ex}" }

class Publisher
  include Celluloid

  def initialize
    async.start
  end

  def start
    connection = Bunny.new(vhost: 'event_hub', :automatic_recovery => false, logger: Logger.new('/dev/null'))
    connection.start
    channel = connection.create_channel
    channel.confirm_select

    exchange = channel.direct('example', durable: true)

    count = 1
    loop do
      id = SecureRandom.uuid
      data = { body: { id: id } }.to_json

      file = File.open("data/#{id}.json", 'w')
      file.write(data)
      file.close

      exchange.publish(data, persistent: true)

      success = channel.wait_for_confirms

      if !success
        raise 'Published message not confirmed'
      end



      sleep 0.001
      print '.'
      puts '' if (count % 80) == 0
      count += 1
    end

  ensure
    connection.close if connection
  end

end


class Application

  def initialize
    @run = true
    @config = Celluloid::Supervision::Configuration.define([
      {type: Publisher, as: :publisher}
    ])

    @config.injection!(:before_restart, proc do
      puts 'Restarting in 5 seconds...'
      sleep 5
    end )

  end

  def start
    puts 'Publisher has been started'
    @config.deploy
    main_event_loop
    cleanup
    puts 'Publisher has been stopped'
  end

  private

  def main_event_loop
    Signal.trap(:INT) { @run = false }
    while @run
      sleep 0.5
    end
  end

  def cleanup
    Celluloid.shutdown
  end

end

Application.new.start
