require "webrick"
require "json"
require "socket"

# EventHub module
module EventHub
  # Listner Class
  class ActorListenerHttp
    include Celluloid
    include Helper

    DEFAULT_VERSION = "?.?.?"
    DEFAULT_HTTP_RESOURCES = [:heartbeat, :version, :docs, :changelog].freeze
    CONTENT_TYPES = {
      ".css" => "text/css",
      ".svg" => "image/svg+xml",
      ".png" => "image/png",
      ".ico" => "image/x-icon"
    }.freeze

    finalizer :cleanup

    def initialize(args = {})
      @processor = args[:processor]
      @host = args[:bind_address] || http_config(:bind_address)
      @port = args[:port] || http_config(:port)
      @base_path = args[:base_path] || http_config(:base_path)
      start
    end

    def start
      EventHub.logger.info("Listener http is starting [#{@host}, #{@port}, #{@base_path}]...")
      @async_server = Thread.new do
        @server = WEBrick::HTTPServer.new(
          BindAddress: @host,
          Port: @port,
          Logger: WEBrick::Log.new(File::NULL),
          AccessLog: []
        )
        mount_resources
        @server.start
      end
    end

    def mount_resources
      # Redirect base path to docs
      @server.mount_proc @base_path do |req, res|
        handle_base_redirect(req, res)
      end
      @server.mount_proc "#{@base_path}/" do |req, res|
        handle_base_redirect(req, res)
      end

      # API resources
      @server.mount_proc "#{@base_path}/heartbeat" do |req, res|
        resource_enabled?(:heartbeat) ? handle_heartbeat_request(req, res) : handle_not_found(res)
      end
      @server.mount_proc "#{@base_path}/version" do |req, res|
        resource_enabled?(:version) ? handle_version_request(req, res) : handle_not_found(res)
      end

      # Documentation resources
      @server.mount_proc "#{@base_path}/docs" do |req, res|
        resource_enabled?(:docs) ? handle_docs_request(req, res) : handle_not_found(res)
      end
      @server.mount_proc "#{@base_path}/docs/changelog" do |req, res|
        resource_enabled?(:changelog) ? handle_changelog_request(req, res) : handle_not_found(res)
      end
      @server.mount_proc "#{@base_path}/docs/configuration" do |req, res|
        resource_enabled?(:configuration) ? handle_config_request(req, res) : handle_not_found(res)
      end

      # Assets
      @server.mount_proc "#{@base_path}/assets" do |req, res|
        handle_asset_request(req, res)
      end
    end

    def handle_base_redirect(req, res)
      case req.request_method
      when "GET"
        res.status = 302
        res["Location"] = "#{@base_path}/docs"
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def handle_heartbeat_request(req, res)
      case req.request_method
      when "GET"
        res.status = 200
        res["Content-Type"] = "application/json"
        res.body = JSON.generate(heartbeat_data)
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def handle_version_request(req, res)
      case req.request_method
      when "GET"
        res.status = 200
        res["Content-Type"] = "application/json"
        res.body = JSON.generate({version: processor_version})
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def handle_docs_request(req, res)
      case req.request_method
      when "GET"
        res.status = 200
        res["Content-Type"] = "text/html; charset=utf-8"
        res.body = docs_renderer.render_readme
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def handle_changelog_request(req, res)
      case req.request_method
      when "GET"
        res.status = 200
        res["Content-Type"] = "text/html; charset=utf-8"
        res.body = docs_renderer.render_changelog
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def handle_config_request(req, res)
      case req.request_method
      when "GET"
        res.status = 200
        res["Content-Type"] = "text/html; charset=utf-8"
        res.body = docs_renderer.render_config
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def handle_asset_request(req, res)
      case req.request_method
      when "GET"
        # Extract asset name from path: /base_path/assets/filename.ext
        asset_name = req.path.sub("#{@base_path}/assets/", "")
        content = docs_renderer.asset(asset_name)

        if content
          ext = File.extname(asset_name)
          res.status = 200
          res["Content-Type"] = CONTENT_TYPES[ext] || "application/octet-stream"
          res.body = content
        else
          res.status = 404
          res.body = "Not Found"
        end
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def processor_version
      return DEFAULT_VERSION unless @processor
      return DEFAULT_VERSION unless @processor.class.method_defined?(:version)
      @processor.version
    end

    def cleanup
      EventHub.logger.info("Listener http is cleaning up...")
      @async_server&.kill
    end

    private

    def http_config(key)
      # Prefer deprecated heartbeat config for backward compatibility,
      # fall back to http config. Only warn when values actually differ.
      heartbeat_value = EventHub::Configuration.server.dig(:heartbeat, key)
      http_value = EventHub::Configuration.server.dig(:http, key)

      if heartbeat_value && http_value && heartbeat_value != http_value
        EventHub.logger.warn("[DEPRECATION] heartbeat.#{key} is deprecated. Please use http.#{key} instead.")
        return heartbeat_value
      end

      http_value || heartbeat_value
    end

    def resource_enabled?(name)
      enabled_http_resources.include?(name)
    end

    def handle_not_found(res)
      res.status = 404
      res.body = "Not Found"
    end

    def enabled_http_resources
      return DEFAULT_HTTP_RESOURCES unless @processor
      return DEFAULT_HTTP_RESOURCES unless @processor.class.method_defined?(:http_resources)
      @processor.http_resources
    end

    def docs_renderer
      @docs_renderer ||= DocsRenderer.new(processor: @processor, base_path: @base_path)
    end

    def heartbeat_data
      now = Time.now
      started = processor_started_at

      {
        version: processor_version,
        pid: Process.pid,
        environment: EventHub::Configuration.environment,
        heartbeat: {
          started: now_stamp(started),
          stamp_last_request: now_stamp(now),
          uptime_in_ms: ((now - started) * 1000).to_i,
          heartbeat_cycle_in_ms: Configuration.processor[:heartbeat_cycle_in_s] * 1000,
          queues_consuming_from: EventHub::Configuration.processor[:listener_queues],
          queues_publishing_to: [EventHub::EH_X_INBOUND],
          host: Socket.gethostname,
          addresses: network_addresses,
          messages: messages_statistics
        }
      }
    end

    def processor_started_at
      return Time.now unless @processor
      return Time.now unless @processor.respond_to?(:started_at)
      @processor.started_at
    end

    def processor_statistics
      return nil unless @processor
      return nil unless @processor.respond_to?(:statistics)
      @processor.statistics
    end

    def network_addresses
      interfaces = Socket.getifaddrs.select { |interface|
        !interface.addr.ipv4_loopback? && !interface.addr.ipv6_loopback?
      }

      interfaces.map { |interface|
        begin
          {
            interface: interface.name,
            host_name: Socket.gethostname,
            ip_address: interface.addr.ip_address
          }
        rescue
          nil
        end
      }.compact
    end

    def messages_statistics
      stats = processor_statistics
      return {} unless stats

      {
        total: stats.messages_total,
        successful: stats.messages_successful,
        unsuccessful: stats.messages_unsuccessful,
        average_size: stats.messages_average_size,
        average_process_time_in_ms: (stats.messages_average_process_time * 1000).to_i,
        total_process_time_in_ms: (stats.messages_total_process_time * 1000).to_i
      }
    end
  end
end
