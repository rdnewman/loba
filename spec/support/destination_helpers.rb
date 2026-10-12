module DestinationHelpers
  # Where a record goes, for specs that pass a sink and maybe a logger.
  def destination_to(sink, logger: nil)
    log_mirror = (Lba::Internal::Destination::LogMirror.new(logger:) if logger)
    Lba::Internal::Destination.new(sink:, log_mirror:)
  end
end
