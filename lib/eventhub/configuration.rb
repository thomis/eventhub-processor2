# EventHub module
module EventHub
  # Configuraiton module
  module Configuration
    # it's a singleton (don't allow to instantiate this class)
    extend self
    extend Helper

    attr_reader :name # name of processor
    attr_reader :environment # environment the processor is running
    attr_reader :detached # run processor run as a daemon
    attr_reader :config_file # name of configuration file
    attr_reader :config_data # data from configuration file

    @name = "undefined"
    @environment = "development"
    @detached = false
    @config_file = File.join(Dir.getwd, "config", "#{@name}.json")
    @config_data = {}

    # set name of processor
    def name=(value)
      @name = value
    end

    def reset
      @name = "undefined"
      @environment = "development"
      @detached = false
      @config_file = File.join(Dir.getwd, "config", "#{@name}.json")
      @config_data = {}
    end

    # parse options from argument list
    def parse_options(argv = ARGV)
      @config_file = File.join(Dir.getwd, "config", "#{@name}.json")

      OptionParser.new { |opts|
        note = "Define environment"
        opts.on("-e", "--environment ENVIRONMENT", note) do |environment|
          @environment = environment
        end

        opts.on("-d", "--detached", "Run processor detached as a daemon") do
          @detached = true
        end

        note = "Define configuration file"
        opts.on("-c", "--config CONFIG", note) do |config|
          @config_file = config
        end
      }.parse!(argv)

      true
    rescue OptionParser::InvalidOption => e
      EventHub.logger.warn("Argument Parsing: #{e}")
      false
    rescue OptionParser::MissingArgument => e
      EventHub.logger.warn("Argument Parsing: #{e}")
      false
    end

    # load configuration from file
    def load!(args = {})
      # for better rspec testing
      @config_file = args[:config_file] if args[:config_file]
      @environment = args[:environment] if args[:environment]

      new_data = {}
      begin
        new_data = JSON.parse(File.read(@config_file), symbolize_names: true)
      rescue => e
        EventHub.logger.warn("Exception while loading configuration file: #{e}")
        EventHub.logger.info("Using default configuration values")
      end

      deep_merge!(@config_data, default_configuration)
      new_data = new_data[@environment.to_sym]
      deep_merge!(@config_data, new_data)
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
      @config_data[name.to_sym] ||
        fail(NoMethodError, "unknown configuration [#{name}]", caller)
    end

    def respond_to_missing?(name, include_private = false)
      return true if @config_data[name.to_sym]
      false
    end

    def default_configuration
      {
        server: {
          user: "guest",
          password: "guest",
          host: "localhost",
          vhost: "event_hub",
          port: 5672,
          tls: false,
          tls_cert: nil,
          tls_key: nil,
          tls_ca_certificates: [],
          verify_peer: false,
          show_bunny_logs: false
        },
        processor: {
          heartbeat_cycle_in_s: 300,
          watchdog_cycle_in_s: 60,
          restart_in_s: 15,
          listener_queues: [@name]
        }
      }
    end

    def instance
      warn "[DEPRECATION] `instance` is deprecated. Please use new" \
           " configuration access method."
      self
    end

    def data
      warn "[DEPRECATION] `data` is deprecated. Please use new configuration" \
           " access method."
      stringify_keys(@config_data)
    end
  end
end
