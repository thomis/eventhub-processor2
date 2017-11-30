docker run -d --name myrabbit -p 4369:4369 -p 5671:5671 -p 5672:5672 -p 15672:15672 rabbitmq
docker exec myrabbit rabbitmq-plugins enable rabbitmq_management
