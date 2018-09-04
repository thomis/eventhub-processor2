## Docker Container

eventhub-processor2 interacts with RabbitMQ. For processor development and rspec test's is required to have a running RabbitMQ environment.
Please follow these steps to build and run a docker container with a predefined virtual host, exchanges, and queues.

* Have latest docker community edition installed (https://www.docker.com)
* cd into the docker folder
* docker-compose up --no-start
* docker-compose start

Is the docker container running fine?
Go to http://localhost:15672 and login to RabbitMQ Management Console with guest/guest

Additional information for RabbitMQ docker image: https://hub.docker.com/r/_/rabbitmq/
