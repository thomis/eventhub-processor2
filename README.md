[![Gem Version](https://badge.fury.io/rb/eventhub-processor2.svg)](https://badge.fury.io/rb/eventhub-processor2)
[![Maintainability](https://api.codeclimate.com/v1/badges/9112358562f0614e0e02/maintainability)](https://codeclimate.com/github/thomis/eventhub-processor2/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/9112358562f0614e0e02/test_coverage)](https://codeclimate.com/github/thomis/eventhub-processor2/test_coverage)
[![ci](https://github.com/thomis/eventhub-processor2/actions/workflows/ci.yml/badge.svg)](https://github.com/thomis/eventhub-processor2/actions/workflows/ci.yml)

# EventHub::Processor2

Next generation gem to build ruby based eventhub processors. Implementation is based on Celluloid, an Actor-based concurrent object framework for Ruby https://celluloid.io. The main idea is to have sub-components in your application and have them supervised and automatically re-booted when they crash.

Processor2 has currently the following sub-components implemented
* Heartbeater - send hearbeats to EventHub dispatcher every x minutes
* Publisher - responsible for message publishing
* Watchdog - Checks regularly broker connection and defined listener queue(s)
* Listener - Listens to defined queues, parses recevied message into a EventHub::Message instance and calls handle_message method as defined in derived class.

Processor2 is using Bunny http://rubybunny.info a feature complete RabbitMQ Client to interact with message broker. Processor2 can deal with long running message processing.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'eventhub-processor2'
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
      '1.0.0' # define your version
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
      publish(message: 'your message as a string') # default exchange_name is 'event_hub.inbound'
      publish(message: 'your message as string', exchange_name: 'your_specfic_exchange')

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
      "show_bunny_logs": false
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
  database['user']              # => "guest"
  database['password']          # => "secret"
  database['name']['subname']   # => "value"
```

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

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/thomis/eventhub-processor2.
