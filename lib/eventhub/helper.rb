require 'optparse'

# EventHub module
module EventHub
  # Helper module
  module Helper
    # Extracts processor name from given class instance.
    # Removes 'EventHub' module from name.

    # Examples:
    # EventHub::Namespace::Demo => namespace.demo
    # EventHub::NameSpace::Demo => name_space.demo
    # EventHub::NameSpace::DemoProcessor => name_space.demo_processor
    # NameSpace::Demo => name_space.demo
    def get_name_from_class(instance)
      instance.class.to_s.split('::').map do |element|
        next if element == 'EventHub'
        element.split(/(?=[A-Z])/).join('_').downcase
      end.compact.join('.')
    end

    def bunny_connection_properties
      server = EventHub::Configuration.server

      if Configuration.server[:tls]
        {
          user: server[:user],
          password: server[:password],
          host: server[:host],
          vhost: server[:vhost],
          port: server[:port],
          tls: server[:tls],
          logger: Logger.new('/dev/null'), # logs from Bunny not required
          network_recovery_interval: 15
        }
      else
        {
          user: server[:user],
          password: server[:password],
          host: server[:host],
          vhost: server[:vhost],
          port: server[:port],
          logger: Logger.new('/dev/null'), # logs from Bunny not required
          network_recovery_interval: 15
        }
      end
    end

    # Formats stamp into UTC format
    def now_stamp(now=nil)
      now ||= Time.now
      now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6NZ")
    end
  end
end
