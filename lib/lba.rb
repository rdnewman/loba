require_relative "lba/version"
require_relative "lba/errors"
require_relative "lba/internal/serialization"
require_relative "lba/internal/caller_binding"
require_relative "lba/internal/label"
require_relative "lba/internal/call_site_tracker"
require_relative "lba/internal/platform/within_rails"
require_relative "lba/internal/log_mirror"
require_relative "lba/internal/settings"
require_relative "lba/internal/run"
require_relative "lba/internal/record_stamp"
require_relative "lba/internal/sink_resolver"
require_relative "lba/internal/writer"
require_relative "lba/internal/value"
require_relative "lba/value"

# lba: structured, AI-consumable trace-debugging.
module Lba
  class << self
    # Alias for Lba.val.
    # @!method value(argument, label: nil, inspect: true, log: nil, logger: nil, sink: nil)
    alias value val
  end
end
