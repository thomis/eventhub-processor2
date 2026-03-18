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

      it "renders each hash with indexed section header" do
        html = renderer.render_config
        expect(html).to include("connections[0]")
        expect(html).to include("connections[1]")
        expect(html).to include("db1.example.com")
        expect(html).to include("db2.example.com")
      end
    end

    context "with mixed array (hashes and scalars)" do
      before do
        EventHub::Configuration.config_data[:items] = [
          {name: "first"},
          "plain_value"
        ]
      end

      it "renders hashes as sections and scalars as indexed rows" do
        html = renderer.render_config
        expect(html).to include("items[0]")
        expect(html).to include("first")
        expect(html).to include("items[1]")
        expect(html).to include("plain_value")
      end
    end

    context "with simple array" do
      it "renders as comma-separated values" do
        html = renderer.render_config
        expect(html).to include("processor2")
      end
    end
  end
end
