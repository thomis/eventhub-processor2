# EventHub patches for upstream gems.
#
# Celluloid 0.18 (the last released version, ~2016) is incompatible with
# Ruby 3.x frozen-string-literal defaults. Its `Internals::Logger.crash`
# mutates string literals like:
#
#     def crash(string, exception)
#       if Celluloid.log_actor_crashes
#         string << "\n" << format_exception(exception)   # FrozenError under Ruby 3.x
#         error string
#       end
#       @exception_handlers.each { |h| h.call(exception) }
#     end
#
# The `string << ...` raises FrozenError BEFORE the registered exception
# handlers fire. The actor thread then dies silently:
#   * no exit event is sent to the supervisor (no restart),
#   * no exit event is sent to linked sub-actors (they stay alive as zombies),
#   * no error is logged anywhere.
#
# Externally the symptom is: an actor whose method raises (e.g. our
# `ActorListenerAmqp#restart` raising "Listener amqp is restarting...") appears
# to be entering the raise but never actually dies, and the listener never
# gets restarted. We hit this in 1.28.0 testing: SIGHUP looked like it
# worked (Configuration reloaded, async.restart enqueued, restart entered)
# but the listener silently became a zombie.
#
# Upstream fix is unlikely - Celluloid is unmaintained. We prepend a corrected
# `crash` that defrosts the input string before mutating it. Behavior is
# otherwise identical to the original.
module EventHub
  module Patches
    module CelluloidLoggerCrash
      def crash(string, exception)
        message = +String(string)
        if Celluloid.log_actor_crashes
          message << "\n" << format_exception(exception)
          error message
        end

        @exception_handlers.each do |handler|
          handler.call(exception)
        rescue => ex
          error(+"EXCEPTION HANDLER CRASHED:\n" << format_exception(ex))
        end
      end
    end
  end
end

Celluloid::Internals::Logger.singleton_class.prepend(EventHub::Patches::CelluloidLoggerCrash)
