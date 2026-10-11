require_relative "../record_stamp"
require_relative "../writer"

module Lba
  module Internal
    # Classes that each build and write one kind of record.
    module Records
      # The record a capped call site writes to count the calls it skipped.
      class Suppression
        # Writes one suppression record; shorthand for
        # +new(**fields).write(destination:)+.
        #
        # @param destination (see #write)
        # @param fields [Hash] the keywords of #initialize
        # @return (see #write)
        def self.write(destination:, **fields) = new(**fields).write(destination:)

        # @param site [Site] the call site that skipped the calls
        # @param suppressed_count [Integer] calls the site skipped
        # @param seq [Integer] this record's order among all the process's records
        def initialize(site:, suppressed_count:, seq:)
          @site = site
          @suppressed_count = suppressed_count
          @seq = seq
        end

        # @param destination [Destination] where to write, and log
        # @return [void]
        def write(destination:)
          destination.write(fields)
        end

      private

        attr_reader :site, :suppressed_count, :seq

        def fields
          {
            **RecordStamp.fields(seq:, type: site.type),
            file: site.file,
            line: site.line,
            suppressed: true,
            suppressed_count:
          }
        end
      end
    end
  end
end
