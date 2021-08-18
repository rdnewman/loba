require 'spec_helper'

require 'simplecov'
SimpleCov.start { add_filter 'spec/' }

require 'loba'

# include spec/support
Dir.glob(
  File.expand_path(File.join(File.dirname(__FILE__), 'support', '**', '*.rb'))
).sort.each { |f| require f }
