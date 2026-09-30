require_relative "lba/version"
require_relative "lba/errors"
require_relative "lba/internal"
require_relative "lba/value"
require_relative "lba/timestamp"

# lba: structured, AI-consumable trace-debugging.
module Lba
  class << self
    # Alias for Lba.value.
    # @!method val(argument, label: nil, inspect: true, log: nil, logger: nil, sink: nil)
    alias val value

    # Alias for Lba.timestamp.
    # @!method ts(label: nil, log: nil, logger: nil, sink: nil)
    alias ts timestamp
  end
end
