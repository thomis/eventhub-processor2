# to collect test coverage
require "simplecov"
SimpleCov.start do
  # Performance spec is opt-in (rake test:performance) and its `it` body
  # isn't executed in `rake spec` runs, so don't let it skew lib coverage.
  add_filter "spec/eventhub/performance_spec.rb"
end

require "celluloid/test"
require_relative "../lib/eventhub/base"
require_relative "support/support"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # config.order = :random
  # Kernel.srand config.seed
end
