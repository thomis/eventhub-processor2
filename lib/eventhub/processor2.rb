require_relative 'version'
require_relative 'helper'
require_relative 'configuration'
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

      start_watchdog
      start_heartbeat
      start_listen

      puts "#{@name}: has been started"
      @thread_group.list.each(&:join)
      puts "#{@name}: has been stopped"
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

    def start_listen
      listen_thread = Thread.new do
        listener = Eventhub::Listener.new(configuration: @configuration)
        listener.start
      end
      @thread_group.add(listen_thread)
    end

    def start_watchdog
      watchdog_thread = Thread.new do
        loop do
          puts 'watchdog...'
          sleep Configuration.processor[:watchdog_cycle_in_s]
        end
      end
      @thread_group.add(watchdog_thread)
    end

    def start_heartbeat
      heatbeat_threat = Thread.new do
        loop do
          puts 'heartbeat...'
          sleep Configuration.processor[:heartbeat_cycle_in_s]
        end
      end
      @thread_group.add(heatbeat_threat)
    end

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
      puts 'Stopping threads...'
      @thread_group.list.each(&:exit)
      puts 'Threads stopped'
    end

    def before_start
      # can be implemented in derived class
    end

    def after_stop
      # can be implemented in derived class
    end
  end
end
