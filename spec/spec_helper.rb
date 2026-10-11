require "simplecov"
SimpleCov.start { skip "spec/" }

require "lba"

Dir.glob(
  File.join(__dir__, "support", "**", "*.rb")
).each do |file|
  require file
end

RSpec.configure do |config|
  config.include MockedRails
  config.include AllocationHelpers
  config.include AtExitHelpers
  config.include TrackerHelpers
  config.include ForkHelpers
  config.include MemoizedCurrentHelpers
  config.include SerializationHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
    mocks.allow_message_expectations_on_nil = false
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus

  # Timing checks depend on the machine running them; run them deliberately
  # with `bundle exec rspec --tag performance`.
  config.filter_run_excluding performance: true
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = "doc" if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end
