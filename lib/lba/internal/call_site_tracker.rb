require_relative "writer"

module Lba
  module Internal
    # Numbers records across the process and per call site, and caps how many
    # records one call site writes per window of time.
    class CallSiteTracker
      # Records one call site may write per window.
      DEFAULT_CAP = 500

      # Length of a window, in seconds.
      DEFAULT_WINDOW = 60

      class << self
        # This process's tracker. On first use it registers an +at_exit+ hook
        # that writes the count of calls skipped at any capped site.
        #
        # A forked child inherits this memo; the pid check gives it fresh counters.
        #
        # @return [CallSiteTracker]
        def current
          return @current if @current&.pid == Process.pid

          @current = new.tap { |tracker| tracker.send(:register_at_exit!) }
        end
      end

      # @return [Integer] the id of the process that created this tracker
      attr_reader :pid

      # Starts with no call sites seen.
      def initialize
        @pid = Process.pid
        @sites = {}
        @global_seq = 0
      end

      # Counts one call at a site, unless the site is capped for its current
      # window. A capped site skips calls until the window ends; the next call
      # after that writes one record counting the calls skipped, and the site
      # starts a new window with a fresh cap. Skipped calls take no numbers.
      #
      # @param site_key [String] the call site, as +"file:line"+
      # @param sink [IO, String, nil] where this site's skipped-call record goes
      # @param cap [Integer] records the site may write per window
      # @param window [Numeric] window length, in seconds
      # @return [Hash{Symbol => Integer, Float, nil}, :suppressed] +:suppressed+
      #   if the site is capped; otherwise:
      #   * +:seq+ [Integer] - this record's order among all the process's records
      #   * +:site_seq+ [Integer] - its order among the site's records
      #   * +:diff+ [Float, nil] - seconds since the site's previous record, or
      #     +nil+ for its first
      def record(site_key, sink: nil, cap: DEFAULT_CAP, window: DEFAULT_WINDOW)
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        site = site_for(site_key)
        refresh_window!(site_key, site, sink:, window:, now:)

        return suppress!(site) if site[:suppressed]

        count_in_window!(site)

        return suppress!(site) if over_cap?(site, cap)

        increment!(site)

        { seq: @global_seq, site_seq: site[:site_seq], diff: advance_diff!(site, now) }
      end

    private

      attr_reader :sites

      def site_for(site_key)
        sites[site_key] ||= {
          site_seq: 0,
          window_count: 0,
          window_start: nil,
          suppressed: false,
          suppressed_count: 0,
          last_mono_time: nil
        }
      end

      def refresh_window!(site_key, site, sink:, window:, now:)
        site[:sink] = sink if sink
        site[:window_start] ||= now

        return unless window_expired?(site, now, window)

        flush!(site_key, site, sink:) if site[:suppressed]
        reset_window!(site, now)
      end

      def window_expired?(site, now, window)
        now - site[:window_start] >= window
      end

      def reset_window!(site, now)
        site[:window_start] = now
        site[:window_count] = 0
        site[:suppressed] = false
        site[:suppressed_count] = 0
      end

      def count_in_window!(site)
        site[:window_count] += 1
      end

      def increment!(site)
        site[:site_seq] += 1
        @global_seq += 1
      end

      def over_cap?(site, cap)
        site[:window_count] > cap
      end

      def advance_diff!(site, now)
        diff = if site[:last_mono_time]
                 now - site[:last_mono_time]
               end
        site[:last_mono_time] = now
        diff
      end

      def suppress!(site)
        site[:suppressed] = true
        site[:suppressed_count] += 1

        :suppressed
      end

      # Forked children inherit this hook; the pid check keeps them from
      # re-flushing the parent's suppressed sites.
      def register_at_exit!
        at_exit { flush_all! if pid == Process.pid }
      end

      def flush_all!
        sites.each do |site_key, site|
          flush!(site_key, site, sink: site[:sink]) if site[:suppressed]
        end
      end

      def flush!(site_key, site, sink:)
        Writer.write(
          {
            type: "val",
            site: site_key,
            suppressed: true,
            suppressed_count: site[:suppressed_count]
          },
          sink:
        )
      end
    end
  end
end
