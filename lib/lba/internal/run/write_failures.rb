require_relative "write_failures/gap"

module Lba
  module Internal
    class Run
      # Keeps track of records that couldn't be written, so a dropped record
      # isn't mistaken for code that never ran. The first failure is reported on
      # $stderr; each sink's unwritten records are then noted on the next record
      # written there (see #unwritten), or summarized at exit if none is (see
      # Run.current).
      class WriteFailures
        # Starts with no failure reported.
        def initialize
          @reported = false
          @unwritten = {}
        end

        # Counts a record that couldn't be written to +sink+, and warns on
        # $stderr about the first such failure in the process.
        #
        # @param sink [IO, String] where the record was to be written
        # @param error [Exception] why it couldn't be
        # @param seq [Integer, nil] the record's +seq+
        # @return [void]
        def report(sink:, error:, seq:)
          count_unwritten(sink, error, seq)
          warn_once(sink, error)
        end

        # The records +sink+ hasn't received since they were last forgotten. They
        # stay until #forget_unwritten, so a write that fails again doesn't lose
        # them.
        #
        # @param sink [IO, String] the sink about to be written
        # @return [Gap, nil] +nil+ if none were missed
        def unwritten(sink)
          @unwritten[sink]
        end

        # Forgets +sink+'s unwritten records, once a record that notes them has
        # been written there.
        #
        # @param sink [IO, String] the sink just written
        # @return [void]
        def forget_unwritten(sink)
          @unwritten.delete(sink)
        end

        # Warns on $stderr, one line per sink, about records never written
        # there and never noted on a later record.
        #
        # @return [void]
        def summarize
          @unwritten.each do |sink, gap|
            warn "lba: #{gap.summary(sink:)}"
          end
        end

      private

        def count_unwritten(sink, error, seq)
          if @unwritten.has_key?(sink)
            @unwritten[sink].add(seq:)
          else
            @unwritten[sink] = Gap.new(error:, seq:)
          end
        end

        def warn_once(sink, error)
          return if @reported

          @reported = true
          warn "lba: couldn't write a record to #{sink.inspect} " \
               "(#{error.class}: #{error.message}); " \
               "later write failures in this process won't be reported"
        end
      end
    end
  end
end
