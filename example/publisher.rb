require_relative '../lib/eventhub/processor2'

connection =Bunny.new
connection.start
channel = connection.create_channel


exchange = channel.direct('example', durable: true)

loop  do
  #sleep 15
  data = rand.to_s
  puts 'Send data...'
  exchange.publish(data, persistent: true)
end

connection.close
