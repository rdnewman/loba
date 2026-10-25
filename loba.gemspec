lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "loba/version"

Gem::Specification.new do |spec|
  spec.name          = "loba".freeze
  spec.version       = Loba::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ["Richard Newman".freeze]
  spec.email         = ["richard@newmanworks.com".freeze]

  spec.summary       = "Loba: structured, AI-consumable trace-debugging.".freeze
  spec.description   = "Handy methods for adding trace lines to a structured, " \
                       "queryable log, built for both human and AI-agent " \
                       "debugging workflows.".freeze
  spec.homepage      = "https://github.com/rdnewman/loba".freeze
  spec.licenses      = ["MIT".freeze]

  spec.files         = Dir["lib/**/*.rb".freeze] +
                       [
                         "LICENSE".freeze,
                         "README.md".freeze
                       ]

  spec.bindir        = "exe".freeze
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib".freeze]
  spec.required_ruby_version = ">= 3.3"

  spec.metadata = {
    "source_code_uri" => "https://github.com/rdnewman/loba",
    "bug_tracker_uri" => "https://github.com/rdnewman/loba/issues",
    "rubygems_mfa_required" => "true"
  }

  spec.add_dependency "debug_inspector", "~> 1.0"
end
