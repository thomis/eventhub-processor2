require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "standard/rake"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.verbose = false
  t.rspec_opts = "--tag ~performance"
end

namespace :test do
  desc "Run throughput baseline against real RabbitMQ (skipped by `rake spec`)"
  RSpec::Core::RakeTask.new(:performance) do |t|
    t.verbose = false
    t.rspec_opts = "--tag performance --format documentation"
  end
end

desc "Initialize or reset rabbitmq docker container (run before rspec)"
task :init do
  sh "cd docker && ./reset"
  puts "You may need to give rabbitmq container a bit time to startup properly..."
end

task default: [:spec, :standard]
