[![Dependency Status](https://gemnasium.com/badges/github.com/thomis/eventhub-processor2.svg)](https://gemnasium.com/github.com/thomis/eventhub-processor2)
[![Maintainability](https://api.codeclimate.com/v1/badges/9112358562f0614e0e02/maintainability)](https://codeclimate.com/github/thomis/eventhub-processor2/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/9112358562f0614e0e02/test_coverage)](https://codeclimate.com/github/thomis/eventhub-processor2/test_coverage)
[![Build Status](https://travis-ci.org/thomis/eventhub-processor2.svg?branch=master)](https://travis-ci.org/thomis/eventhub-processor2)

# EventHub::Processor2

Next generation gem to build ruby based eventhub processor.

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
  class Example

    def handle_message(message, args = {})

      # deal with your parsed EventHub message
      # message.class => EventHub::Message

      # args is a hash with currently following keys
      # => :queue_name (used when listening to multiple queues)
      # => :content_type
      # => :priority
      # => :delivery_tag

      # if an exception is raised in your code
      # it will be automatically catched by
      # the processor2 gem and returned
      # to the event_hub.inbound queue

      message # return message if sucessfull processing
      [ message, new_message1, new_message2] # you can return an array of messages
      nil # or [] if there is no message to the event_hub.inbound queue
    end

  end

  # start your processor instance
  Example.new.start
```

Start your processor and pass optional arguments
```
> bundle exec ruby example.rb --help
Usage: example [options]
    -e, --environment ENVIRONMENT    Define environment (default development)
    -d, --detached                   Run processor detached as a daemon
    -c, --config CONFIG              Define configuration file

> bundle exec ruby example.rb

I, [2018-02-09T15:22:35.649646 #37966]  INFO -- : example (1.1.0): has been started
I, [2018-02-09T15:22:35.652592 #37966]  INFO -- : Heartbeat is starting...
I, [2018-02-09T15:22:35.657200 #37966]  INFO -- : Publisher is starting...
I, [2018-02-09T15:22:35.657903 #37966]  INFO -- : Watchdog is starting...
I, [2018-02-09T15:22:35.658336 #37966]  INFO -- : Running watchdog...
I, [2018-02-09T15:22:35.658522 #37966]  INFO -- : Listener is starting...
I, [2018-02-09T15:22:35.699161 #37966]  INFO -- : Listening to queue [example]
```
Note: If config file is not provided it is derived from class name > ./config/example.json

A processor2 configuration file looks as follows
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
      "tls_cert": nil,
      "tls_key": nil,
      "tls_ca_certificates": [],
      "verify_peer": false,
      "show_bunny_logs": false
    },
    "processor": {
      "listener_queues": [
        "NAME_OF_PROCESSOR_CLASS"
      ],
      "heartbeat_cycle_in_s": 300,
      "watchdog_cycle_in_s": 15,
      "restart_in_s": 15
    }
  }
}

```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/thomis/eventhub-processor2.
