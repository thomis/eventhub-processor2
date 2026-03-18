[![Gem Version](https://badge.fury.io/rb/eventhub-processor2.svg)](https://badge.fury.io/rb/eventhub-processor2)
[![01 - Test](https://github.com/thomis/eventhub-processor2/actions/workflows/01_test.yml/badge.svg)](https://github.com/thomis/eventhub-processor2/actions/workflows/01_test.yml)
[![02 - Test, Build and Release](https://github.com/thomis/eventhub-processor2/actions/workflows/02_test_build_and_release.yml/badge.svg)](https://github.com/thomis/eventhub-processor2/actions/workflows/02_test_build_and_release.yml)

# EventHub::Processor2

Next generation gem to build ruby based eventhub processors. Implementation is based on Celluloid, an Actor-based concurrent object framework for Ruby https://celluloid.io. The main idea is to have sub-components in your application and have them supervised and automatically re-booted when they crash.

Processor2 has currently the following sub-components implemented
* Heartbeater - send hearbeats to EventHub dispatcher every x minutes
* Publisher - responsible for message publishing
* Watchdog - Checks regularly broker connection and defined listener queue(s)
* Listener AMQP - Listens to defined AMQP queues, parses recevied message into a EventHub::Message instance and calls handle_message method as defined in derived class.
* Listener HTTP - Provides HTTP endpoints for health checks and monitoring (e.g. /svc/{class_name}/heartbeat, /svc/{class_name}/version)

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
      # => :correlation_id (if present in incoming AMQP message)

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

## Logging

By default, Processor2 logs to both stdout (standard format) and a logstash file. For containerized environments (Docker, Kubernetes), use the `--console-log-only` option to output structured JSON logs to stdout only:

```bash
bundle exec ruby example.rb --console-log-only
```

This outputs logs in JSON format suitable for log aggregation systems:

```json
{"@timestamp":"2026-01-18T10:00:00.000Z","@version":"1","severity":"INFO","host":"server1","application":"example","environment":"production","message":"example (1.0.0): has been started"}
```

## Correlation ID

Processor2 supports automatic propagation of correlation IDs for distributed tracing. While EventHub messages already contain an `execution_id` in the message body for tracing, the AMQP `correlation_id` provides an additional benefit: it's part of the message metadata (envelope), not the payload. This means it's available even when the JSON body is invalid and cannot be parsed - useful for error tracking and debugging malformed messages.

When an incoming AMQP message includes a `correlation_id` in its metadata:

1. **Automatic logging**: All log messages during message processing will include `correlation_id` as a separate field in structured JSON output
2. **Automatic publishing**: Any messages published during processing will automatically include the same correlation_id in their AMQP headers
3. **Available in args**: The correlation_id is passed to `handle_message` via `args[:correlation_id]`
4. **Consistent execution_id**: When creating new messages, `execution_id` is automatically set to match `correlation_id`, ensuring consistent tracing across both AMQP metadata and message body

This happens transparently without any changes to your `handle_message` implementation:

```ruby
def handle_message(message, args = {})
  # correlation_id is available in args if needed
  correlation_id = args[:correlation_id]

  # Logging automatically includes correlation_id in JSON output
  EventHub.logger.info("Processing order")

  # Publishing automatically includes correlation_id
  publish(message: response.to_json)

  message.copy
end
```

You can also explicitly set or override the correlation_id when publishing:

```ruby
publish(message: msg.to_json, correlation_id: "550e8400-e29b-41d4-a716-446655440000")
```

If no `correlation_id` is present in the AMQP metadata, the message body's `execution_id` is used as fallback to ensure tracing continuity.

### How it works

1. **Received**: When an AMQP message arrives, `correlation_id` is extracted from the message metadata
2. **Fallback**: If no `correlation_id` in AMQP metadata, the message body's `execution_id` is used instead (ensuring tracing continuity)
3. **Stored**: The value is stored in thread-local storage (`Thread.current`) for the duration of message processing
4. **Passed**: The `correlation_id` is passed to `handle_message` via `args[:correlation_id]`
5. **Logging**: The logger automatically reads from thread-local storage and includes it in JSON output
6. **Publishing**: The publisher automatically reads from thread-local storage and adds it to outgoing AMQP message headers (can be overwritten by passing `correlation_id:` explicitly)
7. **New messages**: When creating a new `EventHub::Message`:
   - With `correlation_id` present → `execution_id` is set to match `correlation_id`
   - Without `correlation_id` → `execution_id` is set to a new UUID (default behavior)
8. **Cleared**: After message processing completes, the stored value is cleared

This design ensures correlation_id flows transparently through the entire message processing lifecycle. No code changes are required for existing implementations - just update the processor2 gem dependency.

**Note:** We use `correlation_id` (snake_case) to follow Ruby naming conventions, AMQP standard message properties, and stay consistent with other args keys like `:queue_name`, `:content_type`, etc. The `correlation_id` value is typically a UUID (e.g., `550e8400-e29b-41d4-a716-446655440000`).

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
      "http": {
        "bind_address": "localhost",
        "port": 8080,
        "base_path": "/svc/{class_name}"
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

## HTTP Resources

Processor2 exposes HTTP resources for health checks and monitoring. All resources share the same HTTP server configuration.

**Configuration:**
```json
{
  "server": {
    "http": {
      "bind_address": "localhost",
      "port": 8080,
      "base_path": "/svc/{class_name}"
    }
  }
}
```

Resources are mounted under the `base_path`:
- `{base_path}/heartbeat` - Health check
- `{base_path}/version` - Version info as JSON
- `{base_path}/docs` - README documentation as HTML
- `{base_path}/docs/changelog` - CHANGELOG as HTML
- `{base_path}/assets/*` - Static assets (CSS, images)

Accessing `{base_path}` or `{base_path}/` redirects to `{base_path}/docs`.

**Backward Compatibility:** If you have existing configuration using the old `heartbeat` block with `bind_address`, `port`, and `path`, it will continue to work. The new `http` configuration takes precedence when both are present.

### Heartbeat

Returns detailed processor status information as JSON.

```
GET {base_path}/heartbeat
```

**Response:** `200 OK` with JSON body
```json
{
  "version": "1.0.0",
  "pid": 12345,
  "environment": "production",
  "heartbeat": {
    "started": "2026-01-18T10:00:00.000Z",
    "stamp_last_request": "2026-01-18T12:30:00.000Z",
    "uptime_in_ms": 9000000,
    "heartbeat_cycle_in_ms": 300000,
    "queues_consuming_from": ["my_processor"],
    "queues_publishing_to": ["event_hub.inbound"],
    "host": "server1.example.com",
    "addresses": [
      {"interface": "en0", "host_name": "server1", "ip_address": "192.168.1.100"}
    ],
    "messages": {
      "total": 1000,
      "successful": 995,
      "unsuccessful": 5,
      "average_size": 2048,
      "average_process_time_in_ms": 50,
      "total_process_time_in_ms": 50000
    }
  }
}
```

### Version

Returns the processor version as JSON.

```
GET {base_path}/version
```

**Response:** `200 OK` with JSON body
```json
{
  "version": "1.0.0"
}
```

The version is taken from the `version` method in your derived processor class. If not defined, it returns `"?.?.?"`.

```ruby
class MyProcessor < EventHub::Processor2
  def version
    "1.0.0"  # your version
  end
end
```

### Docs

Serves README.md as HTML with a built-in layout.

```
GET {base_path}/docs
```

**Response:** `200 OK` with HTML page

By default, looks for `README.md` in the current directory, then `doc/README.md`. You can customize the path via configuration:

```json
{
  "server": {
    "http": {
      "docs": {
        "readme_path": "/custom/path/to/README.md"
      }
    }
  }
}
```

Or override completely by defining a `readme_as_html` method in your processor:

```ruby
class MyProcessor < EventHub::Processor2
  def readme_as_html
    "<h1>Custom Documentation</h1><p>Your content here.</p>"
  end
end
```

### Changelog

Serves CHANGELOG.md as HTML with a built-in layout.

```
GET {base_path}/docs/changelog
```

**Response:** `200 OK` with HTML page

By default, looks for `CHANGELOG.md` in the current directory, then `doc/CHANGELOG.md`. You can customize the path via configuration:

```json
{
  "server": {
    "http": {
      "docs": {
        "changelog_path": "/custom/path/to/CHANGELOG.md"
      }
    }
  }
}
```

Or override completely by defining a `changelog_as_html` method in your processor:

```ruby
class MyProcessor < EventHub::Processor2
  def changelog_as_html
    "<h1>Custom Changelog</h1><p>Your changes here.</p>"
  end
end
```

### Customizing Footer

The documentation pages display company name, version, and environment in the footer. Company name defaults to "Novartis" but can be customized by defining a `company_name` method in your processor:

```ruby
class MyProcessor < EventHub::Processor2
  def company_name
    "My Company"
  end
end
```

**Future Extension:** A future version could allow overriding the default layout template and CSS assets using convention over configuration (e.g., placing custom files in `doc/layout.erb` or `doc/app.css`).

## Development

```
  # Get the source code
  git clone https://github.com/thomis/eventhub-processor2.git

  # Install dependencies
  bundle

  # Setup rabbitmq docker container with initial definitions. This can be run multiple times to get your container back into an initial state
  bundle exec rake init

  # Run all rspec tests
  bundle exec rake
```

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Publishing

This project uses [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/) to securely publish gems to RubyGems.org. Trusted Publishing eliminates the need for long-lived API tokens by using OpenID Connect (OIDC) to establish a trusted relationship between GitHub Actions and RubyGems.org.

With Trusted Publishing configured, gem releases are automatically published to RubyGems when the release workflow runs, providing a more secure and streamlined publishing process.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/thomis/eventhub-processor2.
