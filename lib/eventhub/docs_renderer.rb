require "erb"
require "kramdown"

module EventHub
  class DocsRenderer
    ASSETS_PATH = File.expand_path("assets", __dir__)
    TEMPLATES_PATH = File.expand_path("templates", __dir__)

    DEFAULT_README_LOCATIONS = ["README.md", "doc/README.md"].freeze
    DEFAULT_CHANGELOG_LOCATIONS = ["CHANGELOG.md", "doc/CHANGELOG.md"].freeze
    DEFAULT_COMPANY_NAME = "Novartis"

    def initialize(processor:, base_path:)
      @processor = processor
      @base_path = base_path
    end

    def render_readme
      content = readme_html
      render_layout(title: "README", content: content, content_class: "")
    end

    def render_changelog
      content = changelog_html
      render_layout(title: "CHANGELOG", content: content, content_class: "changelog")
    end

    def asset(name)
      path = File.join(ASSETS_PATH, name)
      return nil unless File.exist?(path)
      File.read(path)
    end

    private

    def readme_html
      return @processor.readme_as_html if @processor.class.method_defined?(:readme_as_html)

      markdown = load_markdown(:readme)
      markdown_to_html(markdown)
    end

    def changelog_html
      return @processor.changelog_as_html if @processor.class.method_defined?(:changelog_as_html)

      markdown = load_markdown(:changelog)
      markdown_to_html(markdown)
    end

    def load_markdown(type)
      config_path = case type
      when :readme
        EventHub::Configuration.server.dig(:http, :docs, :readme_path)
      when :changelog
        EventHub::Configuration.server.dig(:http, :docs, :changelog_path)
      end

      if config_path && File.exist?(config_path)
        return File.read(config_path)
      end

      locations = case type
      when :readme
        DEFAULT_README_LOCATIONS
      when :changelog
        DEFAULT_CHANGELOG_LOCATIONS
      end

      locations.each do |location|
        path = File.join(Dir.pwd, location)
        return File.read(path) if File.exist?(path)
      end

      "No #{(type == :readme) ? "README" : "CHANGELOG"} available."
    end

    def markdown_to_html(markdown)
      Kramdown::Document.new(markdown).to_html
    end

    def render_layout(title:, content:, content_class: "")
      template_path = File.join(TEMPLATES_PATH, "layout.erb")
      template = File.read(template_path)

      processor_name = EventHub::Configuration.name
      version = processor_version
      environment = EventHub::Configuration.environment
      company_name = processor_company_name
      base_path = @base_path
      year = Time.now.year
      bulma_css = asset("bulma.min.css")
      app_css = asset("app.css")

      ERB.new(template).result(binding)
    end

    def processor_version
      return "?.?.?" unless @processor
      return "?.?.?" unless @processor.class.method_defined?(:version)
      @processor.version
    end

    def processor_company_name
      return DEFAULT_COMPANY_NAME unless @processor
      return DEFAULT_COMPANY_NAME unless @processor.class.method_defined?(:company_name)
      @processor.company_name
    end
  end
end
