#!/usr/bin/env ruby
# Distinguish real orphans from in-flight-at-SIGKILL artifacts.
#
# After the publisher is SIGKILLed, three states can exist in data/:
#   * file + UUID in store.json   - publisher was mid-transaction; expected residual.
#                                    A real restart would cleanup via TransactionStore.
#   * file + UUID NOT in store    - publisher confirmed delivery but receiver never
#                                    deleted the file. This is a real pipeline loss.
#   * no file + UUID in store     - delivery completed despite SIGKILL; harmless.
#
# We treat only the middle case as a soak FAILURE.
#
# Usage: soak/check_orphans.rb <data_dir>
# Output (single line): "<real_orphan_count> <in_flight_count>"

require "json"

data_dir = ARGV[0] || "soak/data"
store_path = File.join(data_dir, "store.json")
in_flight = (JSON.parse(File.read(store_path)) rescue {}).keys

files = Dir.glob(File.join(data_dir, "*.json"))
  .map { |f| File.basename(f, ".json") }
  .reject { |id| id == "store" }

real_orphans = files - in_flight

puts "#{real_orphans.size} #{in_flight.size}"

if ARGV.include?("--list-orphans") && !real_orphans.empty?
  warn "first 5 real orphan ids:"
  real_orphans.first(5).each { |id| warn "      #{id}" }
end
