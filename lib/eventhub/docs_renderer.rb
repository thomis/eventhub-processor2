require "erb"
require "kramdown"

module EventHub
  class DocsRenderer
    ASSETS_PATH = File.expand_path("assets", __dir__)
    TEMPLATES_PATH = File.expand_path("templates", __dir__)

    DEFAULT_README_LOCATIONS = ["README.md", "doc/README.md"].freeze
    DEFAULT_CHANGELOG_LOCATIONS = ["CHANGELOG.md", "doc/CHANGELOG.md"].freeze
    DEFAULT_COMPANY_NAME = "Novartis"

    DEFAULT_HTTP_RESOURCES = [:heartbeat, :version, :docs, :changelog].freeze

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
      File.read(path, encoding: "utf-8")
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
        return File.read(config_path, encoding: "utf-8")
      end

      locations = case type
      when :readme
        DEFAULT_README_LOCATIONS
      when :changelog
        DEFAULT_CHANGELOG_LOCATIONS
      end

      locations.each do |location|
        path = File.join(Dir.pwd, location)
        return File.read(path, encoding: "utf-8") if File.exist?(path)
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

      filter = '<div class="config-filter">' \
        '<div class="config-filter-row">' \
        '<input type="text" id="config-filter-input" class="input" placeholder="Filter configuration keys..." autocomplete="off">' \
        '<button type="button" id="config-filter-reset" class="config-filter-reset" title="Reset filter">&times;</button>' \
        "</div>" \
        '<p id="config-filter-count" class="config-filter-count"></p>' \
        "</div>"

      script = <<~JS
        <script>
        (function() {
          var input = document.getElementById('config-filter-input');
          var reset = document.getElementById('config-filter-reset');
          var count = document.getElementById('config-filter-count');
          var table = document.querySelector('.config-table');
          if (!input || !table) return;

          input.addEventListener('input', function() {
            var term = this.value.toLowerCase();
            var rows = table.querySelectorAll('tbody tr');
            var visible = 0;
            var total = 0;

            // Filter individual rows by content (includes sub-tables)
            rows.forEach(function(row) {
              if (row.classList.contains('is-section')) {
                row.style.display = '';
                return;
              }
              total++;
              if (!term || row.textContent.toLowerCase().indexOf(term) !== -1) {
                row.style.display = '';
                visible++;
              } else {
                row.style.display = 'none';
              }
            });

            // Hide section headers with no visible rows after them
            var sections = table.querySelectorAll('tbody tr.is-section');
            sections.forEach(function(section) {
              var next = section.nextElementSibling;
              var hasVisible = false;
              while (next && !next.classList.contains('is-section')) {
                if (next.style.display !== 'none') hasVisible = true;
                next = next.nextElementSibling;
              }
              section.style.display = hasVisible ? '' : 'none';
            });

            if (term) {
              count.textContent = visible + ' of ' + total + ' entries';
            } else {
              count.textContent = '';
            }
          });
          reset.addEventListener('click', function() {
            input.value = '';
            input.dispatchEvent(new Event('input'));
            input.focus();
          });
        })();
        </script>
      JS

      intro + filter + config_to_html_table(config) + script
    end

    def config_to_html_table(hash, depth = 0, prefix = "")
      rows = hash.map do |key, value|
        full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
        if depth == 0 && value.is_a?(Hash) && !value.empty?
          "<tr class=\"is-section is-section-top\"><td colspan=\"2\"><strong>#{ERB::Util.html_escape(full_key)}</strong></td></tr>\n" \
          "#{config_to_html_table(value, 1, full_key)}"
        elsif value.is_a?(Hash) && value.empty?
          "<tr><td class=\"config-key\">#{ERB::Util.html_escape(full_key)}</td><td><span class=\"not-set\">(empty)</span></td></tr>"
        elsif value.is_a?(Hash) && value.values.all? { |v| v.is_a?(Hash) && v.empty? }
          items = value.keys.map { |k| "<li>#{ERB::Util.html_escape(k)}</li>" }.join("\n")
          "<tr><td class=\"config-key\">#{ERB::Util.html_escape(full_key)}</td><td><ul class=\"config-array\">#{items}</ul></td></tr>"
        elsif value.is_a?(Hash) && compact_hash?(value)
          "<tr><td class=\"config-key\">#{ERB::Util.html_escape(full_key)}</td><td>#{format_nested_value(value)}</td></tr>"
        elsif value.is_a?(Hash)
          "<tr class=\"is-section\"><td colspan=\"2\"><strong>#{ERB::Util.html_escape(full_key)}</strong></td></tr>\n" \
          "#{config_to_html_table(value, depth + 1, full_key)}"
        elsif value.is_a?(Array)
          format_array_rows(full_key, key, value, depth)
        else
          display_value = if sensitive_key?(key)
            "<span class=\"redacted\">***</span>"
          elsif value.nil? || value.to_s.strip.empty?
            "<span class=\"not-set\">(not set)</span>"
          else
            ERB::Util.html_escape(value.to_s)
          end
          "<tr><td class=\"config-key\">#{ERB::Util.html_escape(full_key)}</td><td>#{display_value}</td></tr>"
        end
      end.join("\n")

      if depth == 0
        "<table class=\"table is-bordered is-striped is-fullwidth config-table\">\n<thead><tr><th>Key</th><th>Value</th></tr></thead>\n<tbody>\n#{rows}\n</tbody>\n</table>"
      else
        rows
      end
    end

    def format_array_rows(full_key, key, array, _depth)
      return "<tr><td class=\"config-key\">#{ERB::Util.html_escape(full_key)}</td><td><span class=\"not-set\">(empty)</span></td></tr>" if array.empty?

      if sensitive_key?(key)
        return "<tr><td class=\"config-key\">#{ERB::Util.html_escape(full_key)}</td><td><span class=\"redacted\">***</span></td></tr>"
      end

      inner = array.map { |item| format_array_item(item) }.join("\n")
      "<tr><td class=\"config-key\">#{ERB::Util.html_escape(full_key)}</td><td><ul class=\"config-array\">#{inner}</ul></td></tr>"
    end

    def format_array_item(item)
      if item.is_a?(Hash)
        rows = item.map do |k, v|
          value = format_nested_value(v)
          "<tr><td>#{ERB::Util.html_escape(k)}</td><td>#{value}</td></tr>"
        end.join
        "<li><table class=\"table is-bordered is-narrow config-subtable\">#{rows}</table></li>"
      elsif item.is_a?(Array)
        inner = item.map { |i| format_array_item(i) }.join("\n")
        "<li><ul class=\"config-array\">#{inner}</ul></li>"
      else
        "<li>#{ERB::Util.html_escape(item.to_s)}</li>"
      end
    end

    def format_nested_value(value)
      if value.is_a?(Hash)
        rows = value.map do |k, v|
          "<tr><td>#{ERB::Util.html_escape(k)}</td><td>#{format_nested_value(v)}</td></tr>"
        end.join
        "<table class=\"table is-bordered is-narrow config-subtable\">#{rows}</table>"
      elsif value.is_a?(Array)
        items = value.map { |i| format_array_item(i) }.join("\n")
        "<ul class=\"config-array\">#{items}</ul>"
      elsif value.nil? || value.to_s.strip.empty?
        "<span class=\"not-set\">(not set)</span>"
      else
        ERB::Util.html_escape(value.to_s)
      end
    end

    def compact_hash?(hash)
      hash.values.all? do |v|
        if v.is_a?(Hash)
          compact_hash?(v)
        else
          !v.is_a?(Array)
        end
      end
    end

    DEFAULT_SENSITIVE_KEYS = %w[password secret token api_key credential username user login].freeze

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
      template = File.read(template_path, encoding: "utf-8")

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
