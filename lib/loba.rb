require_relative "loba/version"
require_relative "loba/errors"
require_relative "loba/internal"
require_relative "loba/value"
require_relative "loba/timestamp"

# loba: structured, AI-consumable trace-debugging.
module Loba
  class << self
    # Alias for Loba.value.
    # @!method val(argument, label: nil, inspect: true, log: nil, logger: nil, sink: nil)
    alias val value

    # Alias for Loba.timestamp.
    # @!method ts(label: nil, log: nil, logger: nil, sink: nil)
    alias ts timestamp
  end
end
