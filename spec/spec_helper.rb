require "codeclimate-test-reporter"
require 'simplecov'
CodeClimate::TestReporter.start
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'loba'

RSpec.configure do |config|
  config.filter_run :focus
  config.run_all_when_everything_filtered = true
end
