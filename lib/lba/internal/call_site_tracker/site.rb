require_relative "window"
require_relative "../records/suppression"

module Lba
  module Internal
    class CallSiteTracker
      # One call site: one record type at one file and line. Numbers and
      # times the site's records, remembers where they go, caps them through
      # its own Window, and writes the record counting any calls it skipped.
      class Site
        # @return [String] the kind of record, e.g. +"val"+
        attr_reader :type

        # @return [String] the calling file
        attr_reader :file

        # @return [Integer] the calling line
        attr_reader :line

        # @return [IO, String, nil] where the site's records go; +nil+ until
        #   a sink is given
        attr_reader :sink

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

        # Numbers one more of the site's records.
        #
        # @param now [Float] a monotonic clock reading
        # @return [Hash{Symbol => Integer, Float, nil}]
        #   * +:site_seq+ [Integer] - the record's order among the site's records
        #   * +:diff+ [Float, nil] - seconds since the site's previous record, or
        #     +nil+ for its first
        def advance(now)
          @site_seq += 1
          { site_seq: @site_seq, diff: advance_diff!(now) }
        end

        # @param sink [IO, String, nil] where the site's records go; +nil+
        #   keeps the current sink
        # @return [void]
        def remember_sink(sink)
          return unless sink

          @sink = sink
        end

        # Rolls the site's window (see Window#roll). If that ends a window
        # that skipped calls, writes a suppression record counting them.
        #
        # @param now [Float] a monotonic clock reading
        # @param length [Numeric] window length, in seconds
        # @yieldreturn [Integer] the suppression record's +seq+; asked for only
        #   when one is written
        # @return [void]
        def roll(now:, length:, &)
          write_suppression(window.roll(now:, length:), &)
        end

        # Writes a suppression record for calls the open window has skipped,
        # if any; for when the process exits.
        #
        # @yieldreturn (see #roll)
        # @return [void]
        def flush(&)
          write_suppression(window.skipped, &)
        end

        # @return (see Window#count_call)
        def count_call(...) = window.count_call(...)

        # @return (see Window#skipping?)
        def skipping? = window.skipping?

      private

        attr_reader :window

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
