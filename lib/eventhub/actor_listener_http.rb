require "webrick"

# EventHub module
module EventHub
  # Listner Class
  class ActorListenerHttp
    include Celluloid
    finalizer :cleanup

    def initialize(host = "0.0.0.0", port: 8091)
      @host = host
      @port = port
      start
    end

    def start
      EventHub.logger.info("Listener http is starting...")
      @async_server = Thread.new do
        @server = WEBrick::HTTPServer.new(Port: @port, BindAddress: @host)
        @server.mount_proc "/" do |req, res|
          handle_request(req, res)
        end
        trap("INT") { @server.shutdown }
        @server.start
      end
    end

    def handle_request(req, res)
      case req.request_method
      when "GET"
        res.status = 200
        res.body = "Hello, World!"
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def cleanup
      EventHub.logger.info("Listener http is cleaning up...")
      @async_server & kill
    end
  end
end
