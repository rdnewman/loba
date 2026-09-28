module Lba
  module Internal
    class CallSiteTracker
      # One call site's current window of time: how many calls it has counted,
      # and how many it has skipped since reaching its cap. Once a window
      # skips a call, it skips every call until it ends.
      class Window
        # @return [Integer] calls skipped in this window
        attr_reader :skipped

        # Starts with no window open; the first #roll opens one.
        def initialize
          @started_at = nil
          @count = 0
          @skipped = 0
        end

        # Opens the window if none is open. If +length+ seconds have passed
        # since it opened, ends it and opens a fresh one, with a fresh cap,
        # starting at +now+.
        #
        # @param now [Float] a monotonic clock reading
        # @param length [Numeric] window length, in seconds
        # @return [Integer] calls the ended window skipped; +0+ if none, or if
        #   the window is still open
        def roll(now:, length:)
          @started_at ||= now
          return 0 unless now - @started_at >= length

          skipped.tap { reset(now) }
        end

        # Counts one call against the cap, skipping it if the cap is reached
        # or the window is already skipping. See #skipping?.
        #
        # @param cap [Integer] calls the window may count before skipping
        # @return [void]
        def count_call(cap:)
          @count += 1
          return unless skipping? || @count > cap

          @skipped += 1
        end

        # @return [Boolean] +true+ once the window has skipped a call, until it ends
        def skipping?
          skipped.positive?
        end

      private

        def reset(now)
          @started_at = now
          @count = 0
          @skipped = 0
        end
      end
    end
  end
end
