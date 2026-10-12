require_relative "window"
require_relative "../records/suppression"

module Lba
  module Internal
    class Tracker
      # What the tracker keeps about one call site. Numbers and times the
      # site's records, remembers where they go, caps them through its own
      # Window, and writes the record counting any calls it skipped.
      class SiteTracker
        # @param site [Site] the call site
        def initialize(site)
          @site = site
          @destination = nil
          @site_seq = 0
          @last_mono_time = nil
          @window = Window.new
        end

        # Handles one call at the site. If the call ends a window that
        # skipped calls, first writes a record counting them. Then counts the
        # call against the cap and, unless it's skipped, numbers it.
        #
        # @param now [Float] a monotonic clock reading
        # @param destination [Destination, nil] where the site's records go;
        #   +nil+ keeps the last destination given
        # @yieldreturn [Integer] the +seq+ for a record counting skipped calls;
        #   asked for only when one is written
        # @return [Hash{Symbol => Integer, Float, nil}, :suppressed] +:suppressed+
        #   if the call is skipped; otherwise:
        #   * +:site_seq+ [Integer] - the call's order among the site's records
        #   * +:diff+ [Float, nil] - seconds since the site's previous record, or
        #     +nil+ for its first
        def record_call(now:, destination:, &)
          remember_destination(destination)
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

        attr_reader :site, :destination, :window

        def remember_destination(destination)
          return unless destination

          @destination = destination
        end

        def roll(now:, &)
          write_suppression(window.roll(now:), &)
        end

        def advance(now)
          @site_seq += 1
          { site_seq: @site_seq, diff: advance_diff(now) }
        end

        def write_suppression(suppressed_count)
          return if suppressed_count.zero?

          destination.write(Records::Suppression.fields(site:, suppressed_count:, seq: yield))
        end

        def advance_diff(now)
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
