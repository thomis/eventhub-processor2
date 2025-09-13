require "webrick"

# EventHub module
module EventHub
  # Listner Class
  class ActorListenerHttp
    include Celluloid

    finalizer :cleanup

    def initialize(args = {})
      @host = args[:bind_address] || EventHub::Configuration.server.dig(:heartbeat, :bind_address)
      @port = args[:port] || EventHub::Configuration.server.dig(:heartbeat, :port)
      @path = args[:path] || EventHub::Configuration.server.dig(:heartbeat, :path)
      start
    end

    def start
      EventHub.logger.info("Listener http is starting [#{@host}, #{@port}, #{@path}]...")
      @async_server = Thread.new do
        @server = WEBrick::HTTPServer.new(
          BindAddress: @host,
          Port: @port,
          Logger: WEBrick::Log.new(File::NULL),
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
        res.body = "OK"
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def cleanup
      EventHub.logger.info("Listener http is cleaning up...")
      @async_server&.kill
    end
  end
end
