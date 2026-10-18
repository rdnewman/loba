require_relative "records/stamp"
require_relative "records/caller"
require_relative "records/label"
require_relative "records/suppression"
require_relative "records/value"
require_relative "records/timestamp"

module Lba
  module Internal
    # Builders of each kind of record's fields (Value, Timestamp, Suppression),
    # and the fields those kinds share (Caller, Label, Stamp).
    module Records
    end
  end
end
