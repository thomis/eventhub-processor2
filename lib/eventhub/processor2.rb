require_relative 'base'

# EventHub module
module EventHub
  # Processor2 class
  class Processor2
    include Helper

    SIGNALS_FOR_TERMINATION = [:INT, :TERM, :QUIT]
    SIGNALS_FOR_RELOAD_CONFIG = [:HUP]
    ALL_SIGNALS = SIGNALS_FOR_TERMINATION + SIGNALS_FOR_RELOAD_CONFIG

    attr_reader :started_at, :statistics

    def initialize(args = {})
      # Set processor name
      EventHub::Configuration.name = args[:name] ||
                                     get_name_from_class(self)

      # Parse comand line options
      EventHub::Configuration.parse_options

      # Load configuration file
      EventHub::Configuration.load!(args)

      @command_queue = []

      @sleeper = EventHub::Sleeper.new
      @started_at = Time.now
      @statistics = EventHub::Statistics.new
    end

    def start
      EventHub.logger.info("#{Configuration.name} (#{version}): has been started")

      before_start
      main_event_loop
      after_stop

      EventHub.logger.info("#{Configuration.name} (#{version}): has been stopped")
    rescue => ex
      EventHub.logger.error("Unexpected error in Processor2.start: #{ex}")
    end

    def stop
      # used by rspec
      @command_queue << :TERM
    end

    def version
      EventHub::VERSION
    end

    # get message as EventHub::Message class instance
    # args contain :queue_name, :content_type, :priority, :delivery_tag
    def handle_message(_message, _args = {})
      raise 'need to be implemented in derived class'
    end

    # pass message as string like: '{ "header": ... , "body": { .. }}'
    # and optionally exchange_name: 'your exchange name'
    def publish(args = {})
      Celluloid::Actor[:actor_publisher].publish(args)
    end

    def before_start
      # can be implemented in derived class
    end

    def after_stop
      # can be implemented in derived class
    end

    private

    def setup_signal_handler
      # have a re-entrant signal handler by just using a simple array
      # https://www.sitepoint.com/the-self-pipe-trick-explained/
      ALL_SIGNALS.each do |signal|
        Signal.trap(signal) { @command_queue << signal }
      end
    end

    def start_supervisor
      @config = Celluloid::Supervision::Configuration.define([
        {type: ActorHeartbeat, as: :actor_heartbeat, args: [ self ]},
        {type: ActorPublisher, as: :actor_publisher, args: [ self ]},
        {type: ActorListener, as: :actor_listener, args: [ self ]}
      ])

      sleeper = @sleeper
      @config.injection!(:before_restart, proc do
        restart_in_s = Configuration.processor[:restart_in_s]
        EventHub.logger.info("Restarting in #{restart_in_s} seconds...")
        sleeper.start(restart_in_s)
      end )

      @config.deploy
    end

    def main_event_loop
      setup_signal_handler
      start_supervisor

      loop do
        command = @command_queue.pop
        case
          when SIGNALS_FOR_TERMINATION.include?(command)
            EventHub.logger.info("Command [#{command}] received")
            @sleeper.stop
            break
          when SIGNALS_FOR_RELOAD_CONFIG.include?(command)
            EventHub::Configuration.load!
            EventHub.logger.info('Configuration file reloaded')

            # restart listener when actor is known
            if Celluloid::Actor[:actor_listener]
              Celluloid::Actor[:actor_listener].async.restart
            else
              EventHub.logger.info('Was unable to get a valid listener actor to restart... check!!!')
            end
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
  end
end
