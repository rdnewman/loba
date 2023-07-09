lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'loba/version'

Gem::Specification.new do |spec|
  spec.name          = 'loba'.freeze
  spec.version       = Loba::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ['Richard Newman'.freeze]
  spec.email         = ['richard@newmanworks.com'.freeze]

  spec.summary       = 'Loba: Easy tracing for debugging.'.freeze
  spec.description   = 'Handy methods for adding trace lines to output or Rails logs.'.freeze
  spec.homepage      = 'https://github.com/rdnewman/loba'.freeze
  spec.licenses      = ['MIT'.freeze]

  spec.files         = Dir['lib/**/*.rb'.freeze] +
                       [
                         'LICENSE'.freeze,
                         'README.md'.freeze,
                         'CHANGELOG.md'.freeze,
                         'CODE_OF_CONDUCT.md'.freeze,
                         'SECURITY.md'.freeze
                       ]

  spec.bindir        = 'exe'.freeze
  spec.executables   = spec.files.grep(/^exe\//) { |f| File.basename(f) }
  spec.require_paths = ['lib'.freeze]
  spec.required_ruby_version = '>= 3.0.6'

  spec.metadata = {
    'source_code_uri' => 'https://github.com/rdnewman/loba',
    'bug_tracker_uri' => 'https://github.com/rdnewman/loba/issues',
    'changelog_uri' => 'https://github.com/rdnewman/loba/blob/main/CHANGELOG.md',
    'documentation_uri' => 'https://www.rubydoc.info/gems/loba',
    'rubygems_mfa_required' => 'true'
  }

  spec.add_dependency 'binding_of_caller', '~> 1.0'
  spec.add_dependency 'rainbow', '~> 3.1'
end
