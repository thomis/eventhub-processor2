require_relative '../lib/eventhub/processor2'

connection =Bunny.new(vhost: 'event_hub')
connection.start
channel = connection.create_channel


exchange = channel.direct('example', durable: true)
run = true

Signal.trap(:INT) { run = false }

puts 'Publisher has been started'
count = 1
while run do
  data = rand.to_s
  exchange.publish(data, persistent: true)

  print '.'
  sleep 0.1
  puts '' if (count % 80) == 0
  count += 1
end

connection.close

puts ''
puts 'Publisher has been stopped'
