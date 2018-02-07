require_relative '../lib/eventhub/sleeper'

# MyProcess
class MyProcess
  attr_reader :id, :name
  def initialize(id, name)
    @id = id
    @name = name
  end

  def restart
    puts "Sending Signal HUP to process [#{@id}/#{@name}]"
    Process.kill('HUP', @id)
  rescue Errno::ESRCH
  end

  def self.all
    processes = []

    ['router', 'receiver'].each do |name|
      data = `ps | grep #{name}.rb`
      data.lines[0..-2].each do |line|
        a = line.split(' ')
        next if a.size > 5
        processes << MyProcess.new(a[0].to_i, a[-1])
      end
    end

    puts "Found ids: #{processes.map{ |pr| pr.id}.join(', ')}"
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
    puts "Restart (#{@time}) [#{@name}]"
    `docker restart -t #{@time} #{@name}`
  end
end

def items
  a = []
  #a << Docker.new('processor-rabbitmq')
  #a << Docker.new('processor-rabbitmq', 0)
  a << MyProcess.all
  a.flatten!

  puts a.map{ |item| item.name }.join(', ')
  a
end

run = true
sleeper = EventHub::Sleeper.new

Signal.trap('INT') {
  run = false
  sleeper.stop
}

while run
  to_sleep = rand(600)
  puts "Waiting #{to_sleep} seconds..."
  sleeper.start(to_sleep)
  break unless run
  items.sample.restart
end

puts 'Done'
