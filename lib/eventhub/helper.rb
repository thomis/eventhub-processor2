require 'optparse'

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
      instance.class.to_s.split('::').map { |element|
        next if element == 'Eventhub'
        element.split(/(?=[A-Z])/).join('_').downcase
      }.compact.join('.')
    end

    # Parses command line options into a hash
    def self.parse_options
      options = { environment: 'development', detached: false}

      OptionParser.new do |opts|
        opts.on('-e', '--environment ENVIRONMENT', 'Define environment') do |e|
          options[:environment] = e
        end

        opts.on('-d', '--detached', 'Run processor detached as a daemon') do
          options[:detached] = true
        end

        opts.on('-c', '--config CONFIG', 'Define configuration file') do |c|
          options[:config] = c
        end

      end.parse!

      options
    rescue OptionParser::MissingArgument => e
      puts "Argument Parsing: #{e.to_s}"
      options
    end

  end
end
