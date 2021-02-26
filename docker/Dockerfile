FROM rabbitmq:3.8.12-management

LABEL maintainer="thomas.steiner@ikey.ch"

ADD definitions.json /etc/rabbitmq/
ADD rabbitmq.config /etc/rabbitmq/
RUN chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq.config /etc/rabbitmq/definitions.json
RUN rabbitmq-plugins enable rabbitmq_web_stomp
