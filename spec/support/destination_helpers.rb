module DestinationHelpers
  # Where a record goes, for specs that pass a sink and maybe a logger.
  def destination_to(sink, logger: nil)
    log_mirror = (Loba::Internal::Destination::LogMirror.new(logger:) if logger)
    Loba::Internal::Destination.new(sink: Loba::Internal::Destination::Sink.new(sink), log_mirror:)
  end
end
