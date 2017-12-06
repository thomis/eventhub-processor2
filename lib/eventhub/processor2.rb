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

    def handle_message(message, args = {})
      raise 'need to be implemented in derived class'
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
        {type: ActorListener, as: :actor_listener, args: [ self ]}
      ])

      @config.injection!(:before_restart, proc do
        EventHub.logger.info('Restarting in 10 seconds...')
        sleep 10
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
            break
          when SIGNALS_FOR_RELOAD_CONFIG.include?(command)
            EventHub::Configuration.load!
            EventHub.logger.info('Configuration file reloaded')
            Celluloid::Actor[:actor_listener].async.restart
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
