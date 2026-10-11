module DestinationHelpers
  # Where a record goes, for specs that pass a sink and maybe a logger.
  def destination_to(sink, logger: nil) = Lba::Internal::Destination.new(sink:, logger:)
end
