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

    def self.bunny_connection_properties
      server = Eventhub::Configuration.server

      if Configuration.server[:tls]
        {
          user: server[:user],
          password: server[:password],
          host: server[:host],
          vhost: server[:vhost],
          port: server[:port],
          tls: server[:tls]
        }
      else
        {
          user: server[:user],
          password: server[:password],
          host: server[:host],
          vhost: server[:vhost],
          port: server[:port]
        }
      end
    end
  end
end
