require 'eventhub/components'
require 'logstash-logger'
require 'bunny'

require_relative 'version'
require_relative 'logger'
require_relative 'helper'
require_relative 'configuration'
require_relative 'consumer'
require_relative 'worker'
require_relative 'worker_heartbeat'
require_relative 'worker_watchdog'
require_relative 'worker_listener'

# Eventhub module
module Eventhub
  # Processor2 class
  class Processor2
    SIGNALS_FOR_TERMINATION = ['INT', 'TERM', 'QUIT']
    SIGNAL_FOR_RELOAD_CONFIG = 'HUP'
    SIGNAL_FOR_RESTART = 'USR1'
    ALL_SIGNALS = ['INT', 'TERM', 'QUIT', 'HUP', 'USR1']

    def initialize(args = {})
      # Set processor name
      Eventhub::Configuration.name = args[:name] ||
                                     Eventhub::Helper.get_name_from_class(self)

      # Parse comand line options
      Eventhub::Configuration.parse_options

      # Load configuration file
      Eventhub::Configuration.load!(args)

      @queue_command = []
    end

    def start
      Eventhub.logger.info("#{Configuration.name} #{version} has been started")

      before_start
      Worker.start
      main_event_loop
      Worker.stop
      after_stop

      Eventhub.logger.info("#{Configuration.name} #{version} has been stopped")
    end

    def stop
      # used by rspec
      @queue_command << :TERM
    end

    def version
      Eventhub::VERSION
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
        Signal.trap(signal) { @queue_command << signal }
      end
    end

    def main_event_loop
      setup_signal_handler
      loop do
        command = @queue_command.pop
        case
          when SIGNAL_FOR_RESTART == command
            Eventhub.logger.info("Command [#{command}] received. Restarting in 15s...")
            sleep 15
            Worker.restart
          when SIGNALS_FOR_TERMINATION.include?(command)
            Eventhub.logger.info("Command [#{command}] received")
            break
          when SIGNAL_FOR_RELOAD_CONFIG == command
            Eventhub::Configuration.load!
            Eventhub.logger.info('Configuration file reloaded')
            Worker.restart
          else
            sleep 0.5
        end
      end
    end
  end
end
