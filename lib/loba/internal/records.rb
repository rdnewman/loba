require_relative "records/json"
require_relative "records/stamp"
require_relative "records/caller"
require_relative "records/label"
require_relative "records/suppression"
require_relative "records/value"
require_relative "records/timestamp"

module Loba
  module Internal
    # Builders of each kind of record's fields (Value, Timestamp, Suppression),
    # the fields those kinds share (Caller, Label, Stamp), and their JSON form
    # (Json).
    module Records
    end
  end
end
