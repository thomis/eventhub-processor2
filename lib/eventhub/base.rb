require "securerandom"
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
require_relative "correlation_id"
require_relative "execution_id"
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
require_relative "actor_listener_amqp"
require_relative "actor_listener_http"
require_relative "docs_renderer"
require_relative "processor2"
require_relative "patches/celluloid_logger"

module EventHub
  # Format a Celluloid actor exception with the dying actor's class name
  # so post-mortem analysis can identify which actor died.
  #
  # Important: inside an actor's crash flow, `Celluloid.current_actor`
  # returns the Proxy::Cell, whose `.class` goes through method_missing /
  # the mailbox - which can hang on a dying actor. Read the raw actor
  # object out of the thread-local instead and walk to the subject class
  # via instance variables (no proxy round-trips).
  def self.format_celluloid_exception(ex)
    actor_name = begin
      actor = Thread.current[:celluloid_actor]
      if actor
        behavior = actor.instance_variable_get(:@behavior)
        subject = behavior&.instance_variable_get(:@subject)
        subject&.class&.name
      end
    rescue
      nil
    end
    prefix = actor_name ? "[#{actor_name}] " : ""
    "#{prefix}Exception occured: #{ex.class}: #{ex.message}"
  end
end

Celluloid.logger = nil
Celluloid.exception_handler { |ex| EventHub.logger.error(EventHub.format_celluloid_exception(ex)) }
