FROM rabbitmq:3.7.7-management

LABEL maintainer="thomas.steiner@ikey.ch"

ADD definitions.json /etc/rabbitmq/
ADD rabbitmq.config /etc/rabbitmq/
RUN chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq.config /etc/rabbitmq/definitions.json
