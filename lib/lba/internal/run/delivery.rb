require "json"
require_relative "delivery/gap"

module Lba
  module Internal
    class Run
      # The run's writing of records to their sinks. A sink that can't be
      # written (a full disk, a read-only file, a closed IO) never breaks the
      # traced code: the record is skipped, and the first such failure in the
      # process is reported on $stderr. So that a dropped record isn't mistaken
      # for code that never ran, the next record written to that sink notes
      # what it missed, in +:unwritten+; what no later record notes is
      # summarized at exit (see Run.current).
      class Delivery
        # Starts with nothing missed and no failure reported.
        def initialize
          @reported = false
          @gaps = {}
        end

        # Appends the record to the sink as one line of JSON, noting on it the
        # records the sink missed since the last one written there, if any.
        #
        # If the sink can't be written, the record is skipped and counted
        # toward the sink's gap. Any other error is lba's own bug, and raises.
        #
        # @param fields [Hash] the record
        # @param to [Destination::Sink] where the record goes
        # @return [void]
        def write(fields, to:)
          append(fields, to)
        rescue SystemCallError, IOError => e
          count_unwritten(to, e, fields[:seq])
          warn_once(to, e)
        end

        # Warns on $stderr, one line per sink, about records never written
        # there and never noted on a later record.
        #
        # @return [void]
        def summarize
          gaps.each do |sink, gap|
            warn "lba: #{gap.summary(sink:)}"
          end
        end

      private

        attr_reader :gaps

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

        def warn_once(sink, error)
          return if @reported

          @reported = true
          warn "lba: couldn't write a record to #{sink} " \
               "(#{error.class}: #{error.message}); " \
               "later write failures in this process won't be reported"
        end
      end
    end
  end
end
