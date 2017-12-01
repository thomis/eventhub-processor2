# Eventhub module
module Eventhub
  # Listner Class
  class WorkerListener < Worker
    register(:listener)

    def initialize(args = {})
      @connection = nil
    end

    def start
      listen
    end

    def stop
      @connection.stop if @connection
    end

    def listen
      begin
        @connection = Bunny.new(Eventhub::Helper.bunny_connection_properties)
        @connection.start
      rescue Bunny::Exception => ex
        Eventhub.logger.error("Unexpected exception in listener [#{ex.class}]: #{ex}")
      end

      threads = []
      Eventhub::Configuration.processor[:listener_queues].each_with_index do |queue_name, index|
        threads << Thread.new do
          begin
            channel = @connection.create_channel
            channel.prefetch(1)
            queue = channel.queue(queue_name, durable: true)

            consumer = Eventhub::Consumer.new(channel,
                                              queue,
                                              Eventhub::Configuration.name + '-' + index.to_s,
                                              false)

            Eventhub.logger.info("Listening to queue [#{queue_name}]")
            consumer.on_delivery do |delivery_info, metadata, payload|
              begin
                Eventhub.logger.info("#{queue_name}: [#{delivery_info.delivery_tag}] delivery")

                channel.acknowledge(delivery_info.delivery_tag, false)
                Eventhub.logger.info("#{queue_name}: [#{delivery_info.delivery_tag}] acknowledged")
              rescue Bunny::Exception => ex
                Eventhub.logger.error("Unexpected exception in listener [#{ex.class}]: #{ex}")
              end
            end

            queue.subscribe_with(consumer, block: true)
          rescue Bunny::Exception => ex
            Eventhub.logger.error("Unexpected exception in listener [#{ex.class}]: #{ex}")
          end
        end
      end

      # wait for all threads to finish
      threads.join(&:join)
      @@queue_terminated << :listener
    end
  end
end
