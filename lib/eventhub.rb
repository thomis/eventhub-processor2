require 'uuidtools'
require 'json'
require 'base64'

require 'eventhub/components'
require 'logstash-logger'
require 'bunny'
require 'celluloid/current'

require_relative 'eventhub/version'
require_relative 'eventhub/constant'
require_relative 'eventhub/logger'
require_relative 'eventhub/helper'
require_relative 'eventhub/hash_extensions'
require_relative 'eventhub/configuration'
require_relative 'eventhub/message'
require_relative 'eventhub/statistics'
require_relative 'eventhub/consumer'
require_relative 'eventhub/actor_heartbeat'
require_relative 'eventhub/actor_watchdog'
require_relative 'eventhub/actor_listener'
require_relative 'eventhub/processor2'

Celluloid.logger = nil
Celluloid.exception_handler { |ex| EventHub.logger.info "Exception occured: #{ex}" }
