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
require_relative "lba/internal/sink_resolver"
require_relative "lba/internal/writer"

# lba: structured, AI-consumable trace-debugging.
module Lba
end
