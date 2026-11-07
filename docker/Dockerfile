FROM rabbitmq:management-alpine

LABEL maintainer="thomas.steiner@ikey.ch"

ADD definitions.json /etc/rabbitmq/
ADD rabbitmq.conf /etc/rabbitmq/
RUN chown rabbitmq:rabbitmq /etc/rabbitmq/rabbitmq.conf /etc/rabbitmq/definitions.json
