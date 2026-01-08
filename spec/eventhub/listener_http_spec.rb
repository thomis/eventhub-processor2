require "spec_helper"
require "uri"
require "net/http"
require "json"
require "fileutils"

RSpec.describe EventHub::ActorListenerHttp do
  before(:all) do
    # Load default configuration
    EventHub::Configuration.load!

    # Create test docs directory
    @docs_dir = File.join(Dir.getwd, "docs")
    FileUtils.mkdir_p(@docs_dir)
    File.write(File.join(@docs_dir, "README.md"), "# Test README\n\nThis is a test.")
    File.write(File.join(@docs_dir, "CHANGELOG.md"), "# Changelog\n\n## 1.0.0\n- Initial release")
  end

  after(:all) do
    # Clean up test docs
    FileUtils.rm_rf(@docs_dir) if @docs_dir && File.exist?(@docs_dir)
  end

  let(:base_path) { "/svc/processor2" }

  describe "without processor instance" do
    before(:all) do
      @listener = EventHub::ActorListenerHttp.new(nil, {
        bind_address: "localhost",
        port: 8081,
        path: "/svc/processor2/heartbeat"
      })
      sleep 0.3
    end

    after(:all) do
      @listener&.terminate
    end

    it "gives a valid actor" do
      expect(@listener).not_to eq(nil)
    end

    it "succeeds to call heartbeat endpoint" do
      uri = URI("http://localhost:8081#{base_path}/heartbeat")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res.body).to eq("OK")
    end

    it "fails with method not allowed on heartbeat POST" do
      uri = URI("http://localhost:8081#{base_path}/heartbeat")
      res = Net::HTTP.post(uri, nil)

      expect(res.is_a?(Net::HTTPMethodNotAllowed)).to eq(true)
      expect(res.body).to eq("Method Not Allowed")
    end

    it "redirects root to docs" do
      uri = URI("http://localhost:8081/")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri)
      res = http.request(request)

      expect(res.is_a?(Net::HTTPRedirection)).to eq(true)
      expect(res["Location"]).to include("#{base_path}/docs")
    end

    it "returns version as JSON with fallback" do
      uri = URI("http://localhost:8081#{base_path}/version")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res["Content-Type"]).to eq("application/json")

      body = JSON.parse(res.body)
      expect(body["version"]).to eq("?.?.?")
    end

    it "serves docs with Bulma layout" do
      uri = URI("http://localhost:8081#{base_path}/docs")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res["Content-Type"]).to eq("text/html")
      expect(res.body).to include("bulma.min.css")
      expect(res.body).to include("Test README")
      expect(res.body).to include("<nav")
      expect(res.body).to include("<footer")
    end

    it "serves changelog with Bulma layout" do
      uri = URI("http://localhost:8081#{base_path}/changelog")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res["Content-Type"]).to eq("text/html")
      expect(res.body).to include("bulma.min.css")
      expect(res.body).to include("Changelog")
      expect(res.body).to include("Initial release")
    end

    it "serves assets" do
      uri = URI("http://localhost:8081#{base_path}/assets/bulma.min.css")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res["Content-Type"]).to eq("text/css")
      expect(res["Cache-Control"]).to eq("public, max-age=86400")
      expect(res.body).to include("bulma")
    end

    it "serves js assets with correct content type" do
      # Create temporary js file
      js_path = File.join(EventHub::ActorListenerHttp::ASSETS_PATH, "test.js")
      File.write(js_path, "console.log('test');")

      uri = URI("http://localhost:8081#{base_path}/assets/test.js")
      res = Net::HTTP.get_response(uri)

      expect(res["Content-Type"]).to eq("application/javascript")

      FileUtils.rm(js_path)
    end

    it "serves png assets with correct content type" do
      png_path = File.join(EventHub::ActorListenerHttp::ASSETS_PATH, "test.png")
      File.write(png_path, "fake png")

      uri = URI("http://localhost:8081#{base_path}/assets/test.png")
      res = Net::HTTP.get_response(uri)

      expect(res["Content-Type"]).to eq("image/png")

      FileUtils.rm(png_path)
    end

    it "serves jpg assets with correct content type" do
      jpg_path = File.join(EventHub::ActorListenerHttp::ASSETS_PATH, "test.jpg")
      File.write(jpg_path, "fake jpg")

      uri = URI("http://localhost:8081#{base_path}/assets/test.jpg")
      res = Net::HTTP.get_response(uri)

      expect(res["Content-Type"]).to eq("image/jpeg")

      FileUtils.rm(jpg_path)
    end

    it "serves svg assets with correct content type" do
      svg_path = File.join(EventHub::ActorListenerHttp::ASSETS_PATH, "test.svg")
      File.write(svg_path, "<svg></svg>")

      uri = URI("http://localhost:8081#{base_path}/assets/test.svg")
      res = Net::HTTP.get_response(uri)

      expect(res["Content-Type"]).to eq("image/svg+xml")

      FileUtils.rm(svg_path)
    end

    it "serves unknown assets with octet-stream content type" do
      bin_path = File.join(EventHub::ActorListenerHttp::ASSETS_PATH, "test.bin")
      File.write(bin_path, "binary data")

      uri = URI("http://localhost:8081#{base_path}/assets/test.bin")
      res = Net::HTTP.get_response(uri)

      expect(res["Content-Type"]).to eq("application/octet-stream")

      FileUtils.rm(bin_path)
    end

    it "returns 404 for unknown assets" do
      uri = URI("http://localhost:8081#{base_path}/assets/unknown.css")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPNotFound)).to eq(true)
    end
  end

  describe "with missing docs files" do
    before(:all) do
      @listener = EventHub::ActorListenerHttp.new(nil, {
        bind_address: "localhost",
        port: 8084,
        path: "/svc/processor2/heartbeat"
      })
      sleep 0.3

      # Remove docs files temporarily
      @readme_backup = File.read(File.join(Dir.getwd, "docs", "README.md"))
      @changelog_backup = File.read(File.join(Dir.getwd, "docs", "CHANGELOG.md"))
      FileUtils.rm(File.join(Dir.getwd, "docs", "README.md"))
      FileUtils.rm(File.join(Dir.getwd, "docs", "CHANGELOG.md"))
    end

    after(:all) do
      # Restore docs files
      File.write(File.join(Dir.getwd, "docs", "README.md"), @readme_backup)
      File.write(File.join(Dir.getwd, "docs", "CHANGELOG.md"), @changelog_backup)
      @listener&.terminate
    end

    it "shows file not found message for missing README" do
      uri = URI("http://localhost:8084/svc/processor2/docs")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res.body).to include("File not found")
    end

    it "shows file not found message for missing CHANGELOG" do
      uri = URI("http://localhost:8084/svc/processor2/changelog")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res.body).to include("File not found")
    end
  end

  describe "with processor instance" do
    before(:all) do
      processor_class = Class.new do
        def version
          "2.0.0"
        end

        def company_name
          "Test Company"
        end
      end

      @listener = EventHub::ActorListenerHttp.new(processor_class.new, {
        bind_address: "localhost",
        port: 8082,
        path: "/svc/processor2/heartbeat"
      })
      sleep 0.3
    end

    after(:all) do
      @listener&.terminate
    end

    it "returns version from processor" do
      uri = URI("http://localhost:8082#{base_path}/version")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      body = JSON.parse(res.body)
      expect(body["version"]).to eq("2.0.0")
    end

    it "includes company name in footer" do
      uri = URI("http://localhost:8082#{base_path}/docs")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res.body).to include("Copyright Test Company")
    end

    it "includes version in footer" do
      uri = URI("http://localhost:8082#{base_path}/docs")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res.body).to include("2.0.0")
    end
  end

  describe "with custom docs/changelog methods" do
    before(:all) do
      processor_class = Class.new do
        def version
          "3.0.0"
        end

        def docs
          "<html><body>Custom Docs</body></html>"
        end

        def changelog
          "<html><body>Custom Changelog</body></html>"
        end
      end

      @listener = EventHub::ActorListenerHttp.new(processor_class.new, {
        bind_address: "localhost",
        port: 8083,
        path: "/svc/processor2/heartbeat"
      })
      sleep 0.3
    end

    after(:all) do
      @listener&.terminate
    end

    it "uses custom docs method" do
      uri = URI("http://localhost:8083#{base_path}/docs")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res.body).to eq("<html><body>Custom Docs</body></html>")
      expect(res.body).not_to include("bulma")
    end

    it "uses custom changelog method" do
      uri = URI("http://localhost:8083#{base_path}/changelog")
      res = Net::HTTP.get_response(uri)

      expect(res.is_a?(Net::HTTPSuccess)).to eq(true)
      expect(res.body).to eq("<html><body>Custom Changelog</body></html>")
      expect(res.body).not_to include("bulma")
    end
  end
end
