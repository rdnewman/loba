lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'loba/version'

Gem::Specification.new do |spec|
  spec.name          = 'loba'
  spec.version       = Loba::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ['Richard Newman']
  spec.email         = ['richard@newmanworks.com']

  spec.summary       = 'Loba: Easy tracing for debugging.'
  spec.description   = 'Handy methods for adding trace lines to output or Rails logs.'
  spec.homepage      = 'https://github.com/rdnewman/loba'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(/^(test|spec|features)\//)
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(/^exe\//) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 2.1.0'

  spec.add_development_dependency 'bundler', '>= 1.14'
  spec.add_development_dependency 'rake', '>= 12.0'
  spec.add_development_dependency 'rspec', '>= 3.5'

  spec.add_dependency 'binding_of_caller', '>= 0.7'
  spec.add_dependency 'colorize', '>= 0.8'
end
