# Eventhub module
module Eventhub
  # Configuraiton module
  module Configuration
    # it's a singleton (don't allow to instantiate this class)
    extend self
    @data = {}
    attr_reader :data

    # Main entry point to load configuration file data
    def load!(filename = nil, options = {})
      new_data = {}
      environment = options[:environment] || 'development'

      begin
        new_data = JSON.parse(File.read(filename), symbolize_names: true)
      rescue => e
        puts "Exception while loading configuration file: #{e}"
      end

      deep_merge!(@data, default_configuration)
      new_data = new_data[environment.to_sym]
      deep_merge!(@data, new_data)
    end

    # Deep merging of hashes
    # deep_merge by Stefan Rusterholz, see http://www.ruby-forum.com/topic/142809
    def deep_merge!(target, data)
      return if data.nil?
      merger = proc do |_, v1, v2|
        v1.is_a?(Hash) && v2.is_a?(Hash) ? v1.merge(v2, &merger) : v2
      end
      target.merge! data, &merger
    end

    def method_missing(name, *_args, &_block)
      @data[name.to_sym] ||
        fail(NoMethodError, "unknown configuration [#{name}]", caller)
    end

    def default_configuration
      {
        server: {
          user: 'guest',
          password: 'guest',
          host: 'localhost',
          vhost: 'eventhub',
          port: 5672,
          ssl: false
        },
        heartbeat_cycle_in_s: 300,
        watchdog_cycle_in_s: 15
      }
    end
  end
end
