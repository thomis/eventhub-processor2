require "async"
require "async/http/server"
require "async/http/endpoint"
require "async/http/protocol/https"

# EventHub module
module EventHub
  # Listner Class
  class ActorListenerHttp
    include Celluloid
    finalizer :cleanup

    def initialize(host = "0.0.0.0", port: 8090)
      @endpoint = Async::HTTP::Endpoint.parse("http://#{host}:#{port}")
      start(host, port)
    end

    def start(host, port)
      EventHub.logger.info("Listener http is starting...")
      @async_task = Thread.new do
        Async do |task|
          server = Async::HTTP::Server.new(method(:handle_request), @endpoint)
          server.run
        end
      end
    end

    def handle_request(request)
      if request.method == "GET"
        Async::HTTP::Response[200, {}, ["Component is running"]]
      else
        Async::HTTP::Response[405, {}, ["Method Not Allowed"]]
      end
    end

    def cleanup
      EventHub.logger.info("Listener http is cleaning up...")
      @async_task&.kill
    end
  end
end
