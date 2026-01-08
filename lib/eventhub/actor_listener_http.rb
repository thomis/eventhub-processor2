require "webrick"
require "kramdown"

# EventHub module
module EventHub
  # Listner Class
  class ActorListenerHttp
    include Celluloid

    ASSETS_PATH = File.expand_path("assets", __dir__)

    finalizer :cleanup

    def initialize(processor_instance = nil, args = {})
      @processor_instance = processor_instance
      @host = args[:bind_address] || EventHub::Configuration.server.dig(:heartbeat, :bind_address)
      @port = args[:port] || EventHub::Configuration.server.dig(:heartbeat, :port)
      @path = args[:path] || EventHub::Configuration.server.dig(:heartbeat, :path)
      @base_path = File.dirname(@path)
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
        @server.mount_proc "/" do |req, res|
          handle_root(req, res)
        end
        @server.mount_proc "#{@base_path}/heartbeat" do |req, res|
          handle_heartbeat(req, res)
        end
        @server.mount_proc "#{@base_path}/version" do |req, res|
          handle_version(req, res)
        end
        @server.mount_proc "#{@base_path}/docs" do |req, res|
          handle_docs(req, res)
        end
        @server.mount_proc "#{@base_path}/changelog" do |req, res|
          handle_changelog(req, res)
        end
        @server.mount_proc "#{@base_path}/assets" do |req, res|
          handle_assets(req, res)
        end
        @server.start
      end
    end

    def handle_heartbeat(req, res)
      case req.request_method
      when "GET"
        res.status = 200
        res.body = "OK"
      else
        res.status = 405
        res.body = "Method Not Allowed"
      end
    end

    def handle_root(req, res)
      res.status = 302
      res["Location"] = "#{@base_path}/docs"
    end

    def handle_version(req, res)
      res.status = 200
      res["Content-Type"] = "application/json"
      res.body = {version: processor_version}.to_json
    end

    def handle_docs(req, res)
      res.status = 200
      res["Content-Type"] = "text/html"

      # Check if processor defines custom docs method
      if @processor_instance&.respond_to?(:docs)
        res.body = @processor_instance.docs
      else
        # Default: render ./docs/README.md
        readme_path = File.join(Dir.getwd, "docs", "README.md")
        content = render_markdown_file(readme_path)
        res.body = html_layout(content, active: :docs)
      end
    end

    def handle_changelog(req, res)
      res.status = 200
      res["Content-Type"] = "text/html"

      # Check if processor defines custom changelog method
      if @processor_instance&.respond_to?(:changelog)
        res.body = @processor_instance.changelog
      else
        # Default: render ./docs/CHANGELOG.md
        changelog_path = File.join(Dir.getwd, "docs", "CHANGELOG.md")
        content = render_markdown_file(changelog_path)
        res.body = html_layout(content, active: :changelog)
      end
    end

    def handle_assets(req, res)
      # Serve assets from gem's assets directory
      file_name = File.basename(req.path)
      file_path = File.join(ASSETS_PATH, file_name)

      if File.exist?(file_path)
        res.status = 200
        res["Content-Type"] = content_type_for(file_name)
        res["Cache-Control"] = "public, max-age=86400"
        res.body = File.read(file_path)
      else
        res.status = 404
        res.body = "Asset not found"
      end
    end

    def cleanup
      EventHub.logger.info("Listener http is cleaning up...")
      @async_server&.kill
    end

    private

    def processor_version
      @processor_instance&.respond_to?(:version) ? @processor_instance.version : "?.?.?"
    end

    def processor_name
      EventHub::Configuration.name
    end

    def company_name
      @processor_instance&.respond_to?(:company_name) ? @processor_instance.company_name : ""
    end

    def render_markdown_file(path)
      if File.exist?(path)
        markdown = File.read(path)
        Kramdown::Document.new(markdown).to_html
      else
        "<p>File not found: #{path}</p>"
      end
    end

    def content_type_for(filename)
      case File.extname(filename).downcase
      when ".css" then "text/css"
      when ".js" then "application/javascript"
      when ".png" then "image/png"
      when ".jpg", ".jpeg" then "image/jpeg"
      when ".svg" then "image/svg+xml"
      else "application/octet-stream"
      end
    end

    def footer_date
      Time.now.strftime("%Y, %B")
    end

    def html_layout(content, active: :docs)
      docs_active = (active == :docs) ? "has-text-weight-bold" : ""
      changelog_active = (active == :changelog) ? "has-text-weight-bold" : ""
      company = company_name.empty? ? "" : "Copyright #{company_name}"

      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>#{processor_name}</title>
          <link rel="stylesheet" href="#{@base_path}/assets/bulma.min.css">
          <style>
            .content pre { padding: 1.25em 1.5em; }
            .content code { background-color: #f5f5f5; color: #363636; padding: 0.25em 0.5em; }
            .content pre code { padding: 0; background: none; }
          </style>
        </head>
        <body>
          <nav class="navbar is-light" role="navigation">
            <div class="container">
              <div class="navbar-brand">
                <span class="navbar-item has-text-weight-bold">#{processor_name}</span>
              </div>
              <div class="navbar-menu">
                <div class="navbar-end">
                  <a class="navbar-item #{docs_active}" href="#{@base_path}/docs">Docs</a>
                  <a class="navbar-item #{changelog_active}" href="#{@base_path}/changelog">Changelog</a>
                </div>
              </div>
            </div>
          </nav>

          <section class="section">
            <div class="container">
              <div class="content">
                #{content}
              </div>
            </div>
          </section>

          <footer class="footer">
            <div class="container">
              <div class="columns">
                <div class="column">
                  <p><strong>#{processor_name}</strong></p>
                  <p>#{processor_version}</p>
                </div>
                <div class="column has-text-right">
                  <p>#{footer_date}</p>
                  <p>#{company}</p>
                </div>
              </div>
            </div>
          </footer>
        </body>
        </html>
      HTML
    end
  end
end
