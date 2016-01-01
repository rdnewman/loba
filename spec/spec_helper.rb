require "codeclimate-test-reporter"
require 'simplecov'
CodeClimate::TestReporter.start
SimpleCov.start

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'loba'
