require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

ENV['LOBA_SPEC_IN_TRAVIS'] = 'true'

RSpec::Core::RakeTask.new(:spec)

task default: :spec
