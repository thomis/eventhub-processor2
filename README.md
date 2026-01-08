[![Gem Version](https://badge.fury.io/rb/eventhub-processor2.svg)](https://badge.fury.io/rb/eventhub-processor2)
[![ci](https://github.com/thomis/eventhub-processor2/actions/workflows/ci.yml/badge.svg)](https://github.com/thomis/eventhub-processor2/actions/workflows/ci.yml)

# EventHub::Processor2

Next generation gem to build ruby based eventhub processors. Implementation is based on Celluloid, an Actor-based concurrent object framework for Ruby https://celluloid.io. The main idea is to have sub-components in your application and have them supervised and automatically re-booted when they crash.

Processor2 has currently the following sub-components implemented
* Heartbeater - send hearbeats to EventHub dispatcher every x minutes
* Publisher - responsible for message publishing
* Watchdog - Checks regularly broker connection and defined listener queue(s)
* Listener AMQP - Listens to defined AMQP queues, parses recevied message into a EventHub::Message instance and calls handle_message method as defined in derived class.
* Listener HTTP - Provides HTTP endpoints for health checks, version info, and documentation

Processor2 is using Bunny http://rubybunny.info a feature complete RabbitMQ Client to interact with message broker. Processor2 can deal with long running message processing.

## Supported Ruby Versions

Currently supported and tested ruby versions are:

- 3.4 (EOL 2028-03-31)
- 3.3 (EOL 2027-03-31)
- 3.2 (EOL 2026-03-31)

Ruby versions not tested anymore:
- 3.1 (EOL 2025-03-31)
- 3.0 (EOL 2024-04-23)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "eventhub-processor2"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install eventhub-processor2


## Usage

Create example.rb

```ruby
module EventHub
  class Example < Processor2

    def version
      "1.0.0" # define your version
    end

    def handle_message(message, args = {})
      # deal with your parsed EventHub message
      # message.class => EventHub::Message
      puts message.process_name # or whatever you need to do

      # args is a hash with currently following keys
      # => :queue_name (used when listening to multiple queues)
      # => :content_type
      # => :priority
      # => :delivery_tag

      # if an exception is raised in your code
      # it will be automatically catched by
      # the processor2 gem and returned
      # to the event_hub.inbound queue

      # it is possible to publish a message during message processing but it's a
      # good style to return one or multiple messages at end of handle_message
      publish(message: "your message as a string") # default exchange_name is 'event_hub.inbound'
      publish(message: "your message as string", exchange_name: "your_specfic_exchange")

      # at the end return one of
      message_to_return = message.copy # return message if sucessfull processing
                                       # message.copy sets status.code automatically
                                       # to EventHub::STATUS_SUCCESS which signals
                                       # dispatcher successful processing

      # or if you have multiple messages to return to event_hub.inbound queue
      [ message_to_return, new_message1, new_message2]

      # or if there is no message to return to event_hub.inbound queue
      nil # [] works as well
    end
  end
end

# start your processor instance
EventHub::Example.new.start
```

Start your processor and pass optional arguments
```bash
bundle exec ruby example.rb --help
Usage: example [options]
    -e, --environment ENVIRONMENT    Define environment (default development)
    -d, --detached                   Run processor detached as a daemon
    -c, --config CONFIG              Define configuration file
        --console-log-only           Logs to console only (E.g. containers)

bundle exec ruby example.rb
I, [2018-02-09T15:22:35.649646 #37966]  INFO -- : example (1.1.0): has been started
I, [2018-02-09T15:22:35.652592 #37966]  INFO -- : Heartbeat is starting...
I, [2018-02-09T15:22:35.657200 #37966]  INFO -- : Publisher is starting...
I, [2018-02-09T15:22:35.657903 #37966]  INFO -- : Watchdog is starting...
I, [2018-02-09T15:22:35.658336 #37966]  INFO -- : Running watchdog...
I, [2018-02-09T15:22:35.658522 #37966]  INFO -- : Listener is starting...
I, [2018-02-09T15:22:35.699161 #37966]  INFO -- : Listening to queue [example]
```

## Configuration

If --config option is not provided processor tries to load config/{class_name}.json. If file does not exist it loads default values as specified below.

```json
{
  "development": {
    "server": {
      "user": "guest",
      "password": "guest",
      "host": "localhost",
      "vhost": "event_hub",
      "port": 5672,
      "tls": false,
      "tls_cert": null,
      "tls_key": null,
      "tls_ca_certificates": [],
      "verify_peer": false,
      "show_bunny_logs": false,
      "heartbeat": {
        "bind_address": "localhost",
        "port": 8080,
        "path": "/svc/{class_name}/heartbeat"
      }
    },
    "processor": {
      "listener_queues": [
        "{class_name}"
      ],
      "heartbeat_cycle_in_s": 300,
      "watchdog_cycle_in_s": 15,
      "restart_in_s": 15
    }
  }
}
```
Default configuration will dynamically resolve {class_name}. Exp. if your class is called MyClass and is derived from Processor2, value of {class_name} would be "my_class". You can overwrite config settings as needed.

More details about TLS configuration for underlying Bunny gem can be found here: http://rubybunny.info/articles/tls.html.

Feel free to define additional hash key/values (outside of server and processor key) as required by your application.

```json
{
  "development": {
    "server": {
    },
    "processor": {
    },
    "database": {
      "user": "guest",
      "password": "secret",
      "name": {
        "subname": "value"
      }
    }
  }
}
```

Processor2 symbolizes keys and sub-keys from configuration files automatically.
```ruby
  # access configuration values in your application as follows
  EventHub::Configuration.database[:user]             # => "guest"
  EventHub::Configuration.database[:password]         # => "secret"
  EventHub::Configuration.database[:name][:subname]   # => "value"

  # If you need strings instead of symbols you can do
  database = stringify_keys(EventHub::Configuration.database)
  database["user"]              # => "guest"
  database["password"]          # => "secret"
  database["name"]["subname"]   # => "value"
```

Version 1.17 and newer allows you to load and merge more configuration files programmatically. It is expected that load! is called once (implicit during class initialization) and then load_more! zero, one, or multiple times. All additional files loaded with load_more! are hash deep merged into one configuration structure. Exceptions while loading of files will be catched and shown as warnings.
```ruby
  # specify a file
  EventHub::Configuration.load_more!(pattern: "config/another_config.json")

  # specify glob patterns to load multiple files
  EventHub::Configuration.load_more!(pattern: "config/processes/**/*.json")
  EventHub::Configuration.load_more!(pattern: "config/templates/**/*.json")
```
If you have conflicting hashes, the previous settings will be overwritten.

1st file loaded
```json
  {
    "test": {
      "a": "a_value",
      "b": "b_value"
    }
  }
```
2nd file loaded
```json
  {
    "test": {
      "b": "another_value"
    }
  }
```

Final configuration result
```json
  {
    "test": {
      "a": "a_value",
      "b": "another_value"
    }
  }

```

## HTTP Endpoints

The Listener HTTP component provides a documentation site with Bulma CSS styling on the configured port (default: 8080). All endpoints are served under a configurable base path (default: `/svc/{class_name}`):

| Endpoint | Description |
|----------|-------------|
| `/` | Redirects to `{base_path}/docs` |
| `{base_path}/docs` | Renders `./docs/README.md` with Bulma layout |
| `{base_path}/changelog` | Renders `./docs/CHANGELOG.md` with Bulma layout |
| `{base_path}/version` | Returns JSON: `{"version":"1.0.0"}` |
| `{base_path}/heartbeat` | Health check endpoint, returns `OK` |

The base path is derived from the `heartbeat.path` configuration. For example, if `path` is `/svc/my_processor/heartbeat`, then `base_path` is `/svc/my_processor`.

The layout includes a navbar with the processor name and links to Docs/Changelog, plus a footer with version and optional company name.

### Customization Methods

Define these methods in your processor class to customize the HTTP endpoints:

```ruby
module EventHub
  class Example < Processor2

    def version
      "1.0.0"  # Shown in /version and footer
    end

    def company_name
      "Your Company"  # Shown in footer as "Copyright Your Company"
    end

    # Optional: Return custom HTML to completely override /docs
    def docs
      "<html>...your custom HTML...</html>"
    end

    # Optional: Return custom HTML to completely override /changelog
    def changelog
      "<html>...your custom HTML...</html>"
    end
  end
end
```

If `docs` or `changelog` methods are not defined, the default behavior renders the respective markdown files from `./docs/` with the Bulma layout.

## Development

```bash
# Get the source code
git clone https://github.com/thomis/eventhub-processor2.git

# Install dependencies
bundle

# Setup rabbitmq docker container
bundle exec rake docker:start

# Run all rspec tests
bundle exec rake
```

### Docker Tasks

```bash
rake docker:start   # Start RabbitMQ container
rake docker:stop    # Stop RabbitMQ container
rake docker:status  # Show container status
rake docker:logs    # Show container logs
rake docker:reset   # Full reset (stop, remove, rebuild, start)
rake init           # Alias for docker:reset
```

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Publishing

This project uses [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/) to securely publish gems to RubyGems.org. Trusted Publishing eliminates the need for long-lived API tokens by using OpenID Connect (OIDC) to establish a trusted relationship between GitHub Actions and RubyGems.org.

With Trusted Publishing configured, gem releases are automatically published to RubyGems when the release workflow runs, providing a more secure and streamlined publishing process.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/thomis/eventhub-processor2.
