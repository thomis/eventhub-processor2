require 'eventhub/components'
require 'logstash-logger'

require_relative 'version'
require_relative 'logger'
require_relative 'helper'
require_relative 'configuration'
require_relative 'watchdog'
require_relative 'heartbeat'
require_relative 'listener'

# Eventhub module
module Eventhub
  # Processor2 class
  class Processor2
    attr_reader :name, :environment, :detached, :configuration_file

    def initialize(args = {})
      options = Eventhub::Helper.parse_options

      @name = args[:name] || Eventhub::Helper.get_name_from_class(self)
      @environment = args[:environment] || options[:environment]

      Eventhub.set_logger(@name, @environment)

      @detached = args[:detached] || options[:detached]
      @configuration_file = args[:configuration_file] \
        || options[:config] \
        || File.join(Dir.getwd, 'config', "#{@name}.json")

      Eventhub::Configuration.load!(@configuration_file,
                                    environment: @environment)
      @thread_group = ThreadGroup.new
    end

    def start
      before_start

      setup_signal_handler

      Eventhub.logger.info("#{@name}: has been started")

      # start sub components
      [Watchdog, Heartbeat, Listener].each do |item|
        thread = Thread.new do
          item.new.start
        end
        @thread_group.add(thread)
      end

      @thread_group.list.each(&:join)
      Eventhub.logger.info("#{@name}: has been stopped")
    ensure
      after_stop
    end

    def stop
      stop_thread_group
    end

    def version
      Eventhub::VERSION
    end

    private

    def handle_message(message, args = {})
      # to do...
    end

    def setup_signal_handler
      Signal.trap('INT') do
        stop_thread_group
      end

      Signal.trap('HUP') do
        stop_thread_group
      end

      Signal.trap('TERM') do
        stop_thread_group
      end
    end

    def stop_thread_group
      @thread_group.list.each(&:exit)
    end

    def before_start
      # can be implemented in derived class
    end

    def after_stop
      # can be implemented in derived class
    end
  end
end
