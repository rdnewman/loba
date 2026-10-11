require_relative "window"
require_relative "../records/suppression"

module Lba
  module Internal
    class Tracker
      # One call site: one record type at one file and line. Numbers and
      # times the site's records, remembers where they go, caps them through
      # its own Window, and writes the record counting any calls it skipped.
      class Site
        # @param type [String] the kind of record, e.g. +"val"+
        # @param file [String] the calling file
        # @param line [Integer] the calling line
        def initialize(type:, file:, line:)
          @type = type
          @file = file
          @line = line
          @sink = nil
          @site_seq = 0
          @last_mono_time = nil
          @window = Window.new
        end

        # Handles one call at the site. If the call ends a window that
        # skipped calls, first writes a record counting them. Then counts the
        # call against the cap and, unless it's skipped, numbers it.
        #
        # @param now [Float] a monotonic clock reading
        # @param sink [IO, String, nil] where the site's records go; +nil+ keeps
        #   the last sink given
        # @yieldreturn [Integer] the +seq+ for a record counting skipped calls;
        #   asked for only when one is written
        # @return [Hash{Symbol => Integer, Float, nil}, :suppressed] +:suppressed+
        #   if the call is skipped; otherwise:
        #   * +:site_seq+ [Integer] - the call's order among the site's records
        #   * +:diff+ [Float, nil] - seconds since the site's previous record, or
        #     +nil+ for its first
        def record_call(now:, sink:, &)
          remember_sink(sink)
          roll(now:, &)
          window.count_call
          return :suppressed if window.skipping?

          advance(now)
        end

        # Writes a record counting the calls the open window has skipped, if
        # any; for when the process exits.
        #
        # @yieldreturn (see #record_call)
        # @return [void]
        def flush(&)
          write_suppression(window.skipped, &)
        end

      private

        attr_reader :type, :file, :line, :sink, :window

        def remember_sink(sink)
          return unless sink

          @sink = sink
        end

        def roll(now:, &)
          write_suppression(window.roll(now:), &)
        end

        def advance(now)
          @site_seq += 1
          { site_seq: @site_seq, diff: advance_diff!(now) }
        end

        def write_suppression(suppressed_count)
          return if suppressed_count.zero?

          Records::Suppression.write(type:, file:, line:, suppressed_count:, seq: yield, sink:)
        end

        def advance_diff!(now)
          diff = if @last_mono_time
                   now - @last_mono_time
                 end
          @last_mono_time = now
          diff
        end
      end
    end
  end
end
