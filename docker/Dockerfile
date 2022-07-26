FROM rabbitmq:management-alpine

LABEL maintainer="thomas.steiner@ikey.ch"

ADD definitions.json /etc/rabbitmq/
ADD rabbitmq.config /etc/rabbitmq/
RUN chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq.config /etc/rabbitmq/definitions.json
RUN rabbitmq-plugins enable rabbitmq_web_stomp
