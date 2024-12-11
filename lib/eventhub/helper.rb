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
      instance.class.to_s.split("::").map { |element|
        next if element == "EventHub"
        element.split(/(?=[A-Z])/).join("_").downcase
      }.compact.join(".")
    end

    def create_bunny_connection
      server = EventHub::Configuration.server

      protocol = "amqp"
      connection_properties = {}
      connection_properties[:user] = server[:user]
      connection_properties[:pass] = server[:password]
      connection_properties[:vhost] = server[:vhost]

      # inject bunny logs on request
      unless server[:show_bunny_logs]
        connection_properties[:logger] = Logger.new(File::NULL)
      end

      # we don't need it since reactors can deal with it
      connection_properties[:automatically_recover] = false

      # do we do tls?
      if server[:tls]
        protocol = "amqps"
        connection_properties[:tls] = server[:tls]
        connection_properties[:tls_cert] = server[:tls_cert]
        connection_properties[:tls_key] = server[:tls_key]
        connection_properties[:tls_ca_certificates] = server[:tls_ca_certificates]
        connection_properties[:verify_peer] = server[:verify_peer]
      end

      connection_string = "#{protocol}://#{server[:host]}:#{server[:port]}"

      Bunny.new(connection_string, connection_properties)
    end

    # Formats stamp into UTC format
    def now_stamp(now = nil)
      now ||= Time.now
      now.utc.strftime("%Y-%m-%dT%H:%M:%S.%6NZ")
    end

    # stringify hash keys
    def stringify_keys(h)
      JSON.parse(h.to_json)
    end
  end
end
