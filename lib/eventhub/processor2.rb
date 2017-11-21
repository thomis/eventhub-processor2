require_relative 'version'
require_relative 'helper'

module Eventhub
  class Processor2

    attr_reader :name, :environment, :detached, :configuration_file

    def initialize(args={})
      options = Eventhub::Helper.parse_options

      @name = args[:name] || Eventhub::Helper.get_name_from_class(self)

      @environment = args[:environment] || options[:environment]

      @detached = args[:detached] || options[:detached]

      @configuration_file = args[:configuration_file] \
        || options[:config] \
        || File.join( Dir.getwd ,'config', "#{@name}.json")

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

    def version
      Eventhub::VERSION
    end

    private

    def start_listen
      t = Thread.new do
        loop do
          puts 'listen...'
          sleep 1
        end
      end
      @thread_group.add(t)
    end

    def start_watchdog
      t = Thread.new do
        loop do
          puts 'watchdog...'
          sleep 1
        end
      end
      @thread_group.add(t)
    end

    def start_heartbeat
      t = Thread.new do
        loop do
          puts 'heartbeat...'
          sleep 1
        end
      end
      @thread_group.add(t)
    end

    def handle_message(message, args={})
    end

    def setup_signal_handler
      Signal.trap("INT") do
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
      @thread_group.list.each do |t|
        t.exit
      end
      puts 'Threads stopped'
    end

    def before_start
    end

    def after_stop
    end

  end
end
