# MyProcess
class MyProcess
  attr_reader :id
  def initialize(id)
    @id = id
  end

  def restart
    puts "Sending Signal HUP to process [#{@id}]"
    Process.kill('HUP', @id)
  rescue Errno::ESRCH
  end

  def self.all
    processes = []
    data = `ps | grep example.rb | grep ruby`
    data.lines[0..-2].each do |line|
      processes << MyProcess.new(line.split(' ')[0].to_i)
    end

    puts "Found ids: #{processes.map{ |pr| pr.id}.join(', ')}"
    processes
  end
end

# Docker
class Docker
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
  a << Docker.new('processor-rabbitmq')
  a << Docker.new('processor-rabbitmq', 0)
  a << MyProcess.all
  a.flatten!
end

run = true
Signal.trap('INT') { run = false }

while run
  to_sleep = rand(3600)
  puts "Waiting [#{to_sleep}]..."
  sleep to_sleep
  items.sample.restart
end

puts 'Done'
