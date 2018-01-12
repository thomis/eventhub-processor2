# to collect test coverage
require 'simplecov'
SimpleCov.start

# the following line leaves the startup and shutdown
# of Celluloid to the the developer/tester
ENV['RSPEC_PROCESSOR2'] = '1' # to trigger various require in base.rb
require 'celluloid/test'

require 'bundler/setup'
require 'eventhub/base'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
