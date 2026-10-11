require "json"

module Lba
  module Internal
    # Where a call site's records go: a sink, and a Logger to mirror them to
    # when logging.
    #
    # @!attribute [r] sink
    #   @return [IO, String] an IO, or a file path to append to
    # @!attribute [r] logger
    #   @return [Logger, nil] the Logger to mirror records to; +nil+ if not
    #     logging
    Destination = Data.define(:sink, :logger) do
      # Writes the record to the sink, and to the logger at +debug+ level if
      # there is one.
      #
      # @param fields [Hash] the record
      # @return [void]
      def write(fields)
        Writer.write(fields, sink:)
        logger&.debug(JSON.generate(fields))
      end
    end
  end
end
