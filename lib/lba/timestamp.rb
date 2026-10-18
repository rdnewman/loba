module Lba
  # Records a checkpoint: that this line was reached, with the class, method,
  # file, and line it was called from, and the seconds since the previous
  # checkpoint, as one JSON line in this run's sink.
  #
  # Does nothing in a production environment (Rails production, or +RACK_ENV+,
  # +APP_ENV+, or +RAILS_ENV+ set to +production+ outside Rails); there is no
  # override.
  #
  # @param label [String, Symbol] a name for the checkpoint, e.g. +"reached step A"+;
  #   recorded as +label+, or +null+ when not given
  # @param log [Boolean] +true+ to also write the record to +Rails.logger+ (or
  #   +logger+, if given); +false+ to never log, even if +logger+ is given
  #   [default: +false+, unless +logger+ is given]
  # @param logger [Logger] a +Logger+ to also write the record to; implies
  #   +log: true+ unless +log: false+ is given
  # @param sink [IO, String, Pathname] where to write instead of the default: an IO, or a
  #   file path (see the +LBA_SINK+ environment variable for a process-wide
  #   override)
  # @return [void]
  # @raise [ArgumentError] for an unknown keyword, such as +production:+
  # @raise [InvalidLoggerOptionError] if the call would log and +logger+ is
  #   neither +nil+ nor a +Logger+
  #
  # @example Marking a point in the code
  #   def checkout
  #   Lba.ts # putting Lba statements at the far left helps you remember to remove them
  #     charge_card
  #   end
  #   #=> writes {...,"type":"ts",...,"line":2,"class_name":"Cart",
  #   #           "method_name":"checkout",...,"since_prev_ts":null,...}
  # @example Naming the checkpoint
  #   Lba.ts label: "reached step A"
  def self.timestamp(label: nil, log: nil, logger: nil, sink: nil)
    Internal::Invocation.record(
      Internal::Records::Timestamp, options: { label: }, log:, logger:, sink:
    )
  end
end
