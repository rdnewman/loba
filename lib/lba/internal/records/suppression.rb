require_relative "../record_stamp"
require_relative "../writer"

module Lba
  module Internal
    # Classes that each build and write one kind of record.
    module Records
      # The record a capped call site writes to count the calls it skipped.
      class Suppression
        # Writes one suppression record; shorthand for +new(**fields).write(sink:)+.
        #
        # @param sink (see #write)
        # @param fields [Hash] the keywords of #initialize
        # @return (see #write)
        def self.write(sink:, **fields) = new(**fields).write(sink:)

        # @param type [String] the kind of record the site writes, e.g. +"val"+
        # @param file [String] the site's file
        # @param line [Integer] the site's line
        # @param suppressed_count [Integer] calls the site skipped
        # @param seq [Integer] this record's order among all the process's records
        def initialize(type:, file:, line:, suppressed_count:, seq:)
          @type = type
          @file = file
          @line = line
          @suppressed_count = suppressed_count
          @seq = seq
        end

        # @param sink [IO, String, nil] where to write
        # @return [void]
        def write(sink:)
          Writer.write(fields, sink:)
        end

      private

        attr_reader :type, :file, :line, :suppressed_count, :seq

        def fields
          {
            **RecordStamp.fields(seq:, type:),
            file:,
            line:,
            suppressed: true,
            suppressed_count:
          }
        end
      end
    end
  end
end
