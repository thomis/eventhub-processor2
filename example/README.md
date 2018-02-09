## Example Application

### Description

Example folder contains a series of applications in order to test reliability and performance of processor2 gem.

### How does it work?

A message is passed throuhg the following components.
publisher.rb => [example.outbound] => router.rb => [example.inbound] => receiver.rb

1. publisher.rb generates a unique ID, creates a json message with the ID as payload, save the message in a file, and passes the message to example.outbound queue.

2. router.rb receives the message and passes it to exmaple.outbound queue

3. receiver.rb gets the message and deletes the file with the given ID

### Goal
What ever happens to these components (restarted, killed and restarted, stopped and started, message broker killed, stopped and started) if you do a graceful shutdown at the end there should be no message in the /data folder (except store.json).

Graceful shutdown with CTRL-C or TERM signal to pdi
* Stop producer.rb. Leave the other components running until all messages in example.* queues are gone.
* Stop remaining components
* Check ./example/data folder


### How to use?
* Make sure docker container (process-rabbitmq) is running (see [readme](../docker/README.md))
* Start one or more router with: bundle exec ruby router.rb
* Start one or more receiver with: bundle exec ruby receier.rb
* Start one publisher with: bundle exec ruby publisher.rb
* Start one crasher with: bundle exec ruby crasher.rb (or do this manually)

### Note
* Publisher has a simple transaction store implemented to deal with issues between file creation and file publishing. At the end of the publisher process in the cleanup method pending transaction get processed and coresponding files get deleted.
* Watch for huge log files!
