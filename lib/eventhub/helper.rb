require 'optparse'

# Eventhub module
module Eventhub
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
    def self.parse_options(argv=ARGV)
      options = { environment: 'development', detached: false}

      OptionParser.new do |opts|
        opts.on('-e', '--environment ENVIRONMENT', 'Define environment') do |environment|
          options[:environment] = environment
        end

        opts.on('-d', '--detached', 'Run processor detached as a daemon') do
          options[:detached] = true
        end

        opts.on('-c', '--config CONFIG', 'Define configuration file') do |config|
          options[:config] = config
        end
      end.parse!(argv)

      options
    rescue OptionParser::MissingArgument => e
      puts "Argument Parsing: #{e.to_s}"
      options
    end
  end
end
