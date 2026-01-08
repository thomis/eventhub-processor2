require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "standard/rake"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.verbose = false
end

DOCKER_COMPOSE = "docker compose -f docker/docker-compose.yml"
CONTAINER_NAME = "eventhub.rabbitmq"

namespace :docker do
  desc "Start RabbitMQ container"
  task :start do
    sh "#{DOCKER_COMPOSE} up -d"
    puts "RabbitMQ container starting... may need a moment to be ready"
  end

  desc "Stop RabbitMQ container"
  task :stop do
    sh "#{DOCKER_COMPOSE} stop"
  end

  desc "Show RabbitMQ container status"
  task :status do
    sh "#{DOCKER_COMPOSE} ps"
  end

  desc "Show RabbitMQ container logs"
  task :logs do
    sh "#{DOCKER_COMPOSE} logs -f"
  end

  desc "Reset RabbitMQ container (stop, remove, rebuild, start)"
  task :reset do
    sh "#{DOCKER_COMPOSE} stop"
    sh "docker rm #{CONTAINER_NAME} 2>/dev/null || true"
    sh "docker rmi #{CONTAINER_NAME} 2>/dev/null || true"
    sh "#{DOCKER_COMPOSE} up -d --build"
    puts "RabbitMQ container reset... may need a moment to be ready"
  end
end

desc "Initialize or reset rabbitmq docker container (run before rspec)"
task init: ["docker:reset"]

task default: [:spec, :standard]
