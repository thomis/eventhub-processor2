require 'uuidtools'
require 'json'
require 'base64'

require 'eventhub/components'
require 'logstash-logger'
require 'bunny'
require 'celluloid/current'

require_relative 'version'
require_relative 'constant'
require_relative 'logger'
require_relative 'helper'
require_relative 'hash_extensions'
require_relative 'configuration'
require_relative 'message'
require_relative 'statistics'
require_relative 'consumer'
require_relative 'actor_heartbeat'
require_relative 'actor_watchdog'
require_relative 'actor_listener'
require_relative 'processor2'

Celluloid.logger = nil
Celluloid.exception_handler { |ex| EventHub.logger.info "Exception occured: #{ex}" }
