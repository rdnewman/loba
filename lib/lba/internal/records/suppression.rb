require_relative "../record_stamp"

module Lba
  module Internal
    # Classes that each build one kind of record's fields.
    module Records
      # Builds the fields of the record a capped call site writes to count the
      # calls it skipped.
      class Suppression
        # Builds the record's fields; shorthand for +new(...).fields+.
        #
        # @return (see #fields)
        def self.fields(...) = new(...).fields

        # @param site [Site] the call site that skipped the calls
        # @param suppressed_count [Integer] calls the site skipped
        # @param seq [Integer] this record's order among all the process's records
        def initialize(site:, suppressed_count:, seq:)
          @site = site
          @suppressed_count = suppressed_count
          @seq = seq
        end

        # @return [Hash{Symbol => Object}] the record's fields, in order
        def fields
          {
            seq:,
            type: site.type,
            file: site.file,
            line: site.line,
            suppressed: true,
            suppressed_count:,
            **RecordStamp.fields
          }
        end

      private

        attr_reader :site, :suppressed_count, :seq
      end
    end
  end
end
