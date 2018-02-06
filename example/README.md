## Example Application

### Description

Example application is a suite of applicaitons in order to test reliabiliy and performance of processor2 gem.

How does it work?

A message is passed throuhg the following components.
publisher.rb => [example.outbound] => router.rb => [example.inbound] => receiver.rb

1. publisher.rb generates a unique ID, creates a message with the ID as payload, passes the message to example.outbound queue.

2. router.rb receives the message and passes it to exmaple.outbound queue

3. receiver.rb gets the message and deletes the file with the given ID

Goal: What ever happens to these components (restarted, killed and restarted, stopped and started, message broker restarted) if you do a graceful shutdown at the end there should be no message in the /data folder.

Graceful shutdown: Stop producer.rb. Leave the other components running until all messages in example.* queues are gone. Stop remaining components.


### How to use
* Make sure docker container (process-rabbitmq) is running
* Start one or more router.rb
* Start one or more receier.rb
* Start one or more publisher.rb
* Start crasher.rb if you like (or do it manually)

### Note
