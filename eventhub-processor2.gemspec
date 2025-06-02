lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "eventhub/version"

note = "Next generation gem to build ruby based eventhub processor"

Gem::Specification.new do |spec|
  spec.name = "eventhub-processor2"
  spec.version = EventHub::VERSION
  spec.authors = ["Steiner, Thomas"]
  spec.email = ["thomas.steiner@ikey.ch"]

  spec.summary = note
  spec.description = note
  spec.homepage = "https://github.com/thomis/eventhub-processor2"
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "celluloid", "~> 0.18"
  spec.add_dependency "webrick", "~> 1.8"
  spec.add_dependency "bunny", "~> 2.23"
  spec.add_dependency "eventhub-components", "~> 0.4"
  spec.add_dependency "uuidtools", "~> 3.0"
  spec.add_dependency "base64", ">= 0.2", "< 0.4"
  spec.add_dependency "logger", "~> 1.6"

  spec.add_development_dependency "bundler", "~> 2.3"
  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "simplecov", "~> 0.21"
  spec.add_development_dependency "standard", "~> 1.39"
end
