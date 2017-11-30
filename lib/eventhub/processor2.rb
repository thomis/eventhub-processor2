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
    SIGNALS_FOR_TERMINATION = [:INT, :TERM, :QUIT]
    SIGNALS_FOR_RELOAD_CONFIG = [:HUP]
    ALL_SIGNALS = SIGNALS_FOR_TERMINATION + SIGNALS_FOR_RELOAD_CONFIG

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
      Eventhub.logger.info("#{Configuration.name}: has been started")

      before_start
      Worker.start
      main_event_loop
      Worker.stop
      after_stop

      Eventhub.logger.info("#{Configuration.name}: has been stopped")
    end

    def version
      Eventhub::VERSION
    end

    def handle_message(message, args = {})
      raise 'need to be implmented in derived class'
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
          when SIGNALS_FOR_TERMINATION.include?(command)
            Eventhub.logger.info("Command [#{command}] received")
            break
          when SIGNALS_FOR_RELOAD_CONFIG.include?(command)
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
