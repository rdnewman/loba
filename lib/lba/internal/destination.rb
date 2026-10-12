module Lba
  module Internal
    # Where a call site's records go: a sink, and a LogMirror when logging.
    #
    # @!attribute [r] sink
    #   @return [IO, String] an IO, or a file path to append to
    # @!attribute [r] log_mirror
    #   @return [LogMirror, nil] where records are mirrored; +nil+ if not
    #     logging
    Destination = Data.define(:sink, :log_mirror) do
      # Writes the record to the sink, and to the log mirror if there is one.
      #
      # @param fields [Hash] the record
      # @return [void]
      def write(fields)
        Writer.write(fields, sink:)
        log_mirror&.write(fields)
      end
    end
  end
end
