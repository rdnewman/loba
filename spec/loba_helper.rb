require 'spec_helper'

require 'simplecov'
SimpleCov.start { add_filter 'spec/' }

require 'loba'

# include spec/support
Dir.glob(
  File.expand_path(File.join(File.dirname(__FILE__), 'support', '**', '*.rb'))
).each { |f| require f }

RSpec.configure do |config|
  config.include LobaSpecSupport::MockedRails
end
