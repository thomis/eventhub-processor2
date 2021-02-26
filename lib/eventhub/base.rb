require "uuidtools"
require "json"
require "base64"
require "optparse"

require "eventhub/components"
require "logstash-logger"
require "bunny"
require "celluloid"

require_relative "version"
require_relative "constant"
require_relative "base_exception"
require_relative "logger"
require_relative "helper"
require_relative "sleeper"
require_relative "hash_extensions"
require_relative "configuration"
require_relative "message"
require_relative "statistics"
require_relative "consumer"
require_relative "actor_heartbeat"
require_relative "actor_watchdog"
require_relative "actor_publisher"
require_relative "actor_listener"
require_relative "processor2"

Celluloid.logger = nil
Celluloid.exception_handler { |ex| EventHub.logger.error "Exception occured: #{ex}" }
