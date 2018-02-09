require 'eventhub/components'
require_relative '../lib/eventhub/sleeper'

RESTART_RANGES_IN_SECONDS = (30..600).to_a
PROCESS_PATTERNS = ['router', 'receiver']

# Module Crasher
module Crasher
  def self.logger
    unless @logger
      @logger = ::EventHub::Components::MultiLogger.new
      @logger.add_device(Logger.new(STDOUT))
      @logger.add_device(
        EventHub::Components::Logger.logstash('crasher', 'development')
      )
    end
    @logger
  end

  class MyProcess
    attr_reader :id, :name
    def initialize(id, name)
      @id = id
      @name = name
    end

    def restart
      Crasher.logger.info "Sending Signal HUP to process [#{@id}/#{@name}]"
      Process.kill('HUP', @id)
    rescue Errno::ESRCH
    end

    def self.all
      processes = []
      PROCESS_PATTERNS.each do |name|
        data = `ps | grep #{name}.rb`
        data.lines[0..-2].each do |line|
          a = line.split(' ')
          next if a.size > 5
          processes << MyProcess.new(a[0].to_i, a[-1])
        end
      end

      Crasher.logger.info "Found ids: #{processes.map{ |pr| pr.id}.join(', ')}"
      processes
    end
  end

  # Docker
  class Docker
    attr_reader :name

    def initialize(name, time = 10)
      @name = name
      @time = time
    end

    def restart
      Crasher.logger.info "Restart (#{@time}) [#{@name}]"
      `docker restart -t #{@time} #{@name}`
    end
  end


  class Application
    def initialize
      @sleeper = EventHub::Sleeper.new
      @run = true

      Signal.trap('INT') {
        @run = false
        @sleeper.stop
      }
    end

    def pick_process
      processes = []
      processes << Docker.new('processor-rabbitmq')
      processes << Docker.new('processor-rabbitmq', 0)
      processes << MyProcess.all
      processes.flatten.sample
    end

    def start
      Crasher.logger.info "Crasher has been started"
      while @run
        to_sleep = RESTART_RANGES_IN_SECONDS.sample
        Crasher.logger.info "Waiting #{to_sleep} seconds..."
        @sleeper.start(to_sleep)
        next unless @run
        process = pick_process
        process.restart if process
      end
      Crasher.logger.info "Crasher has been stopped"
    end
  end
end

Crasher::Application.new.start
