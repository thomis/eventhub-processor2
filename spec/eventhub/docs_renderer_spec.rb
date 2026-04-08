require "spec_helper"

RSpec.describe EventHub::DocsRenderer do
  before(:each) do
    EventHub::Configuration.reset
    EventHub::Configuration.name = "processor2"
    EventHub::Configuration.load!
  end

  let(:renderer) { EventHub::DocsRenderer.new(processor: nil, base_path: "/svc/test") }

  describe "#render_config" do
    it "renders configuration as HTML table" do
      html = renderer.render_config
      expect(html).to include("config-table")
      expect(html).to include("Configuration")
    end
  end

  describe "#render_readme" do
    context "with custom readme_path configured" do
      before do
        path = File.join(Dir.pwd, "spec", "fixtures", "custom_readme.md")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "# Custom README\nHello from custom path")
        EventHub::Configuration.config_data[:server][:http][:docs][:readme_path] = path
      end

      after do
        path = File.join(Dir.pwd, "spec", "fixtures", "custom_readme.md")
        File.delete(path) if File.exist?(path)
      end

      it "loads readme from configured path" do
        html = renderer.render_readme
        expect(html).to include("Custom README")
        expect(html).to include("Hello from custom path")
      end
    end
  end

  describe "UTF-8 support" do
    context "with Unicode characters in markdown file" do
      before do
        path = File.join(Dir.pwd, "spec", "fixtures", "unicode_readme.md")
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "# Über uns\nGrüße from Zürich! Ñoño 日本語 🎉", encoding: "utf-8")
        EventHub::Configuration.config_data[:server][:http][:docs][:readme_path] = path
      end

      after do
        path = File.join(Dir.pwd, "spec", "fixtures", "unicode_readme.md")
        File.delete(path) if File.exist?(path)
      end

      it "renders Unicode characters correctly" do
        html = renderer.render_readme
        expect(html).to include("Über uns")
        expect(html).to include("Grüße")
        expect(html).to include("Zürich")
        expect(html).to include("Ñoño")
        expect(html).to include("日本語")
        expect(html).to include("🎉")
      end
    end
  end

  describe "#render_changelog" do
    context "when no changelog file exists" do
      it "shows fallback message" do
        allow(File).to receive(:exist?).and_call_original
        EventHub::DocsRenderer::DEFAULT_CHANGELOG_LOCATIONS.each do |loc|
          allow(File).to receive(:exist?).with(File.join(Dir.pwd, loc)).and_return(false)
        end

        html = renderer.render_changelog
        expect(html).to include("No CHANGELOG available.")
      end
    end
  end

  describe "config_to_html_table (via render_config)" do
    context "with array of hashes in config" do
      before do
        EventHub::Configuration.config_data[:connections] = [
          {host: "db1.example.com", port: 5432},
          {host: "db2.example.com", port: 5433}
        ]
      end

      it "renders each hash as a nested sub-table" do
        html = renderer.render_config
        expect(html).to include("config-subtable")
        expect(html).to include("config-array")
        expect(html).to include("db1.example.com")
        expect(html).to include("db2.example.com")
        expect(html).to include("5432")
        expect(html).to include("5433")
      end
    end

    context "with mixed array (hashes and scalars)" do
      before do
        EventHub::Configuration.config_data[:items] = [
          {name: "first"},
          "plain_value"
        ]
      end

      it "renders hashes as sub-tables and scalars as list items" do
        html = renderer.render_config
        expect(html).to include("first")
        expect(html).to include("plain_value")
        expect(html).to include("config-array")
      end
    end

    context "with simple array" do
      it "renders as list items" do
        html = renderer.render_config
        expect(html).to include("config-array")
        expect(html).to include("processor2")
      end
    end

    context "with empty array" do
      before do
        EventHub::Configuration.config_data[:empty_list] = []
      end

      it "renders as (empty)" do
        html = renderer.render_config
        expect(html).to include("(empty)")
      end
    end

    context "with empty hash value" do
      before do
        EventHub::Configuration.config_data[:empty_section] = {}
      end

      it "renders as (empty)" do
        html = renderer.render_config
        expect(html).to include("empty_section")
        expect(html).to include("(empty)")
      end
    end

    context "with hash of all empty hashes (like queues)" do
      before do
        EventHub::Configuration.config_data[:process] = {
          queues: {
            inbound: {},
            order: {},
            load: {},
            feedback: {}
          }
        }
      end

      it "renders keys as list items in a single row" do
        html = renderer.render_config
        expect(html).to include("process.queues")
        expect(html).to include("config-array")
        expect(html).to include("<li>inbound</li>")
        expect(html).to include("<li>feedback</li>")
        expect(html).not_to include("process.queues.inbound")
      end
    end

    context "with flat hash values (like steps with routing_key)" do
      before do
        EventHub::Configuration.config_data[:process] = {
          steps: {
            "1" => {routing_key: "store.load"},
            "2" => {routing_key: "bios.outbound"}
          }
        }
      end

      it "renders flat hashes as compact sub-tables without section headers" do
        html = renderer.render_config
        expect(html).to include("config-subtable")
        expect(html).to include("store.load")
        expect(html).to include("bios.outbound")
        expect(html).not_to include("process.steps.1")
        expect(html).not_to include("process.steps.2")
      end
    end

    context "with deeply nested array of hashes" do
      before do
        EventHub::Configuration.config_data[:steps] = [
          {name: "step1", targets: {queue: "q1", exchange: "ex1"}},
          {name: "step2", targets: {queue: "q2", exchange: "ex2"}}
        ]
      end

      it "renders nested hashes recursively" do
        html = renderer.render_config
        expect(html).to include("step1")
        expect(html).to include("step2")
        expect(html).to include("q1")
        expect(html).to include("ex2")
        expect(html).to include("config-subtable")
      end
    end

    context "with sensitive array key" do
      before do
        EventHub::Configuration.config_data[:auth] = {
          token: ["secret1", "secret2"]
        }
      end

      it "redacts sensitive array values" do
        html = renderer.render_config
        expect(html).to include("***")
        expect(html).not_to include("secret1")
        expect(html).not_to include("secret2")
      end
    end

    context "with nested arrays" do
      before do
        EventHub::Configuration.config_data[:matrix] = {
          grid: [["a", "b"], ["c", "d"]]
        }
      end

      it "renders nested arrays recursively" do
        html = renderer.render_config
        expect(html).to include("config-array")
        expect(html).to include("a")
        expect(html).to include("d")
      end
    end

    context "with array value inside array of hashes" do
      before do
        EventHub::Configuration.config_data[:connections] = [
          {host: "db1", tags: ["primary", "backup"]}
        ]
      end

      it "renders arrays within sub-table values" do
        html = renderer.render_config
        expect(html).to include("db1")
        expect(html).to include("primary")
        expect(html).to include("backup")
        expect(html).to include("config-array")
        expect(html).to include("config-subtable")
      end
    end

    context "with deep non-compact hash" do
      before do
        EventHub::Configuration.config_data[:services] = {
          api: {
            endpoints: {
              health: {path: "/health", method: "GET"}
            }
          }
        }
      end

      it "renders with section headers for non-compact nested hashes" do
        html = renderer.render_config
        expect(html).to include("is-section")
        expect(html).to include("services.api")
        expect(html).to include("/health")
        expect(html).to include("GET")
      end
    end
  end
end
