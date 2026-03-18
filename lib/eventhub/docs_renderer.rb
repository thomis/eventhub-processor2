require "erb"
require "kramdown"

module EventHub
  class DocsRenderer
    ASSETS_PATH = File.expand_path("assets", __dir__)
    TEMPLATES_PATH = File.expand_path("templates", __dir__)

    DEFAULT_README_LOCATIONS = ["README.md", "doc/README.md"].freeze
    DEFAULT_CHANGELOG_LOCATIONS = ["CHANGELOG.md", "doc/CHANGELOG.md"].freeze
    DEFAULT_COMPANY_NAME = "Novartis"

    DEFAULT_HTTP_RESOURCES = [:heartbeat, :version, :docs, :changelog, :configuration].freeze

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

    def render_config
      content = config_html
      render_layout(title: "Configuration", content: content, content_class: "config")
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

    def config_html
      return @processor.configuration_as_html if @processor&.class&.method_defined?(:configuration_as_html)

      config = EventHub::Configuration.config_data
      return "<p>No configuration available.</p>" if config.nil? || config.empty?

      intro = "<h1>Configuration</h1>" \
        "<p>Active configuration for the <strong>#{ERB::Util.html_escape(EventHub::Configuration.environment)}</strong> environment. " \
        "Sensitive values such as passwords, tokens, and keys are automatically redacted.</p>"

      intro + config_to_html_table(config)
    end

    def config_to_html_table(hash, depth = 0)
      rows = hash.map do |key, value|
        if value.is_a?(Hash)
          "<tr class=\"is-section\"><td colspan=\"2\"><strong>#{ERB::Util.html_escape(key)}</strong></td></tr>\n" \
          "#{config_to_html_table(value, depth + 1)}"
        elsif value.is_a?(Array)
          format_array_rows(key, value, depth)
        else
          display_value = sensitive_key?(key) ? "<span class=\"redacted\">[REDACTED]</span>" : ERB::Util.html_escape(value.to_s)
          "<tr><td class=\"config-key\">#{ERB::Util.html_escape(key)}</td><td>#{display_value}</td></tr>"
        end
      end.join("\n")

      if depth == 0
        "<table class=\"table is-bordered is-striped is-fullwidth config-table\">\n<thead><tr><th>Key</th><th>Value</th></tr></thead>\n<tbody>\n#{rows}\n</tbody>\n</table>"
      else
        rows
      end
    end

    def format_array_rows(key, array, depth)
      if array.any? { |item| item.is_a?(Hash) }
        array.each_with_index.map do |item, index|
          if item.is_a?(Hash)
            "<tr class=\"is-section\"><td colspan=\"2\"><strong>#{ERB::Util.html_escape(key)}[#{index}]</strong></td></tr>\n" \
            "#{config_to_html_table(item, depth + 1)}"
          else
            display_value = sensitive_key?(key) ? "<span class=\"redacted\">[REDACTED]</span>" : ERB::Util.html_escape(item.to_s)
            "<tr><td class=\"config-key\">#{ERB::Util.html_escape(key)}[#{index}]</td><td>#{display_value}</td></tr>"
          end
        end.join("\n")
      else
        display_value = sensitive_key?(key) ? "<span class=\"redacted\">[REDACTED]</span>" : ERB::Util.html_escape(array.join(", "))
        "<tr><td class=\"config-key\">#{ERB::Util.html_escape(key)}</td><td>#{display_value}</td></tr>"
      end
    end

    DEFAULT_SENSITIVE_KEYS = %w[password secret token api_key credential].freeze

    def sensitive_key?(key)
      keys = if @processor&.class&.method_defined?(:sensitive_keys)
        @processor.sensitive_keys
      else
        DEFAULT_SENSITIVE_KEYS
      end
      keys.any? { |pattern| key.to_s.downcase == pattern.downcase }
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
      http_resources = processor_http_resources
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

    def processor_http_resources
      return DEFAULT_HTTP_RESOURCES unless @processor
      return DEFAULT_HTTP_RESOURCES unless @processor.class.method_defined?(:http_resources)
      @processor.http_resources
    end
  end
end
