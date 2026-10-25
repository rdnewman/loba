require "json"
require_relative "lock"
require_relative "recorder/gap"

module Loba
  module Internal
    class Run
      # Writes the run's records to their sinks. A sink that can't be
      # written (a full disk, a read-only file, a closed IO) never breaks the
      # traced code: the record is skipped, and the first such failure in the
      # process is reported on $stderr. So that a dropped record isn't mistaken
      # for code that never ran, the next record written to that sink notes
      # what it missed, in +:unwritten+; what no later record notes is
      # summarized at exit (see Run.current).
      #
      # One thread at a time writes, so a gap is noted on exactly one record.
      # Warnings are written after the lock is released, so a blocked $stderr
      # holds up only the thread warning.
      class Recorder
        # Starts with nothing missed and no failure reported.
        def initialize
          @reported = false
          @gaps = {}
          @lock = Lock.new
        end

        # Appends the record to the sink as one line of JSON, noting on it the
        # records the sink missed since the last one written there, if any.
        #
        # If the sink can't be written, the record is skipped and counted
        # toward the sink's gap. Any other error is loba's own bug, and raises.
        #
        # @param fields [Hash] the record
        # @param to [Destination::Sink] where the record goes
        # @return [void]
        def write(fields, to:)
          unreported_error = lock.synchronize { attempt(fields, to) }
          report_failure(to, unreported_error) if unreported_error
        end

        # Warns on $stderr, one line per sink, about records never written
        # there and never noted on a later record.
        #
        # @return [void]
        def summarize
          summaries = lock.synchronize do
            gaps.map { |sink, gap| gap.summary(sink:) }
          end

          summaries.each do |summary|
            warn "loba: #{summary}"
          end
        end

      private

        attr_reader :gaps, :lock

        # Returns the write's error if it's the process's first failure, so
        # the caller reports it; otherwise nil.
        def attempt(fields, sink)
          append(fields, sink)
          nil
        rescue SystemCallError, IOError => e
          count_unwritten(sink, e, fields[:seq])
          first_failure(e)
        end

        # The gap stays in place until the record noting it is written, so an
        # error #write doesn't rescue (a Timeout, say) can't lose it.
        def append(fields, sink)
          gap = gaps[sink]
          sink.append(line(with_gap(fields, gap)))
          gaps.delete(sink) if gap
        end

        def with_gap(fields, gap)
          if gap
            gap.noted_on(fields)
          else
            fields
          end
        end

        def line(fields)
          "#{JSON.generate(fields)}\n"
        end

        def count_unwritten(sink, error, seq)
          if gaps.has_key?(sink)
            gaps[sink].add(seq:)
          else
            gaps[sink] = Gap.new(error:, seq:)
          end
        end

        def first_failure(error)
          return if @reported

          @reported = true
          error
        end

        def report_failure(sink, error)
          warn "loba: couldn't write a record to #{sink} " \
               "(#{error.class}: #{error.message}); " \
               "later write failures in this process won't be reported"
        end
      end
    end
  end
end
