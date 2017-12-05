## Example Application

### Components
* example.rb - is listening to the example queue, reads id from message and deletes file with id in data folder
* publisher.rb - creates a file with name id.json (id=guid) and publishes a json messages with id as content to the example exchange
* crasher.rb - randomly restarts example processes or docker container (processor-rabbitmq)

### How to use
* Make sure docker container (process-rabbitmq) is running
* Start 1 or more example processes (I did 3)
* Start 1 or more publisher processes ( I did 1)
* Start one crasher.rb

### What is the goal
* See how the components work under various conditions. Feel free to manually interact (Exp. kill -9 PID)
* There should be no files left in the data folder when all example messages are consumed

### Note
It can happen that a file gets deleted before message is acknowledged. This message will be processed again and will just log a warning about missing file. Due to the nature of 2 independent processes it can not garanteed that both process transaction are all done or not done at all, but with message acknowledgement and and publisher confirms we can mitigate risk of lost messages.
