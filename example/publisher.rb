require 'bunny'
require 'celluloid/current'
require 'json'
require 'securerandom'
require 'eventhub/components'
require_relative '../lib/eventhub/sleeper'

# Example module
module Example
  def self.logger
    unless @logger
      @logger = ::EventHub::Components::MultiLogger.new
      @logger.add_device(Logger.new(STDOUT))
      @logger.add_device(
        EventHub::Components::Logger.logstash('publisher', 'development')
      )
    end
    @logger
  end
end

SIGNALS_FOR_TERMINATION = [:INT, :TERM, :QUIT]
SIGNALS_FOR_RELOAD_CONFIG = [:HUP]
ALL_SIGNALS = SIGNALS_FOR_TERMINATION + SIGNALS_FOR_RELOAD_CONFIG

Celluloid.logger = nil
Celluloid.exception_handler { |ex| Example.logger.error "Exception occured: #{ex}}" }

# Store to track pending files (files not yet confirmed to be sent)
class TransactionStore
  include Celluloid
  finalizer :cleanup

  def initialize
    @filename = 'data/store.json'
    if File.exist?(@filename)
      cleanup
    else
      File.write(@filename, '{}')
    end
  end

  def start(name)
    store = read_store
    store[name] = Time.now.strftime('%Y-%m-%d %H:%M:%S.%L')
    write_store(store)
  end

  def stop(name)
    store = read_store
    store.delete(name)
    write_store(store)
  end

  def cleanup
    # cleanup pending entries
    Example.logger.info("Cleaning pending transactions...")
    store = read_store
    store.keys.each do |name|
      name = "data/#{name}.json"
      if File.exist?(name)
        File.delete(name)
        Example.logger.info("Deleted: #{name}")
      end
    end
    write_store({})
  end

  private
    def read_store
      JSON.parse(File.read(@filename))
    end

    def write_store(store)
      File.write(@filename, store.to_json)
    end
end

# Publisher
class Publisher
  include Celluloid

  def initialize
    async.start
  end

  def start
    connect
    loop do
      do_the_work
      sleep 0.050
    end
  ensure
    @connection.close if @connection
  end

  private

  def connect
    @connection = Bunny.new(vhost: 'event_hub',
                            automatic_recovery: false,
                            logger: Logger.new('/dev/null'))
    @connection.start
    @channel = @connection.create_channel
    @channel.confirm_select
    @exchange = @channel.direct('example.outbound', durable: true)
  end

  def do_the_work
    #prepare id and content
    id = SecureRandom.uuid
    file_name = "data/#{id}.json"
    data = { body: { id: id } }.to_json

    # start transaction...
    Celluloid::Actor[:transaction_store].start(id)
    File.write(file_name, data)
    Example.logger.info("[#{id}] - Message/File created")

    @exchange.publish(data, persistent: true)
    success = @channel.wait_for_confirms
    if success
      Celluloid::Actor[:transaction_store].stop(id) if Celluloid::Actor[:transaction_store]
      Example.logger.info("[#{id}] - Message sent")
    else
      Example.logger.error("[#{id}] -  Published message not confirmed")
    end
  end
end

# Application
class Application
  def initialize
    @sleeper = EventHub::Sleeper.new
    @command_queue = []
  end

  def start_supervisor
    @config = Celluloid::Supervision::Configuration.define(
      [
        { type: TransactionStore, as: :transaction_store },
        { type: Publisher, as: :publisher }
      ]
    )

    sleeper = @sleeper
    @config.injection!(:before_restart, proc do
      Example.logger.info('Restarting in 15 seconds...')
      sleeper.start(15)
    end)
    @config.deploy
  end

  def start
    Example.logger.info 'Publisher has been started'

    setup_signal_handler
    start_supervisor
    main_event_loop

    Example.logger.info 'Publisher has been stopped'
  end

  private

  def main_event_loop
    loop do
      command = @command_queue.pop
      case
        when SIGNALS_FOR_TERMINATION.include?(command)
          @sleeper.stop
          break
        else
          sleep 0.5
      end
    end

    Celluloid.shutdown
    # make sure all actors are gone
    while Celluloid.running?
      sleep 0.1
    end
  end

  def setup_signal_handler
    # have a re-entrant signal handler by just using a simple array
    # https://www.sitepoint.com/the-self-pipe-trick-explained/
    ALL_SIGNALS.each do |signal|
      Signal.trap(signal) { @command_queue << signal }
    end
  end
end

Application.new.start
