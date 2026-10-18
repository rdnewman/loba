require_relative "internal/serialization"
require_relative "internal/caller_binding"
require_relative "internal/site"
require_relative "internal/platform"
require_relative "internal/run"
require_relative "internal/records"
require_relative "internal/destination"
require_relative "internal/invocation"

module Lba
  # lba's implementation, behind the public +Lba.value+ and +Lba.timestamp+.
  # Not part of the public API; any of it may change.
  module Internal
  end
end
