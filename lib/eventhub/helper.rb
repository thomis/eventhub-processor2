require 'optparse'

# Eventhub module
module Eventhub
  # Helper module
  module Helper
    # Extracts processor name from given class instance.
    # Removes 'Eventhub' module from name.

    # Examples:
    # Eventhub::Namespace::Demo => namespace.demo
    # Eventhub::NameSpace::Demo => name_space.demo
    # Eventhub::NameSpace::DemoProcessor => name_space.demo_processor
    # NameSpace::Demo => name_space.demo
    def self.get_name_from_class(instance)
      instance.class.to_s.split('::').map do |element|
        next if element == 'Eventhub'
        element.split(/(?=[A-Z])/).join('_').downcase
      end.compact.join('.')
    end

    # Parses command line options into a hash
    def self.parse_options(argv = ARGV)
      options = { environment: 'development', detached: false }

      OptionParser.new do |opts|
        note = 'Define environment'
        opts.on('-e', '--environment ENVIRONMENT', note) do |environment|
          options[:environment] = environment
        end

        opts.on('-d', '--detached', 'Run processor detached as a daemon') do
          options[:detached] = true
        end

        note = 'Define configuration file'
        opts.on('-c', '--config CONFIG', note) do |config|
          options[:config] = config
        end
      end.parse!(argv)

      options
    rescue OptionParser::MissingArgument => e
      puts "Argument Parsing: #{e}"
      options
    end
  end
end
