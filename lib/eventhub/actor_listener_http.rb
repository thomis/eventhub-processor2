require "webrick"

# EventHub module
module EventHub
  # Listner Class
  class ActorListenerHttp
    include Celluloid
    finalizer :cleanup

    def initialize(host = "localhost", port = 8080, path = "/status")
      @host = host
      @port = port
      @path = path
      start
    end

    def start
      EventHub.logger.info("Listener http is starting [#{@host}, #{@port}], #{@path}...")
      @async_server = Thread.new do
        @server = WEBrick::HTTPServer.new(
          BindAddress: @host,
          Port: @port,
          Logger: WEBrick::Log.new("/dev/null"),
          AccessLog: []
        )
        @server.mount_proc @path do |req, res|
          handle_request(req, res)
        end
        @server.start
      end
    end

    def handle_request(req, res)
      case req.request_method
      when "GET"
        res.status = 200
        res.body = "Is running"
      else
        res.status = 405
        res.body = "Method not allowed"
      end
    end

    def cleanup
      EventHub.logger.info("Listener http is cleaning up...")
      @async_server&.kill
    end
  end
end
