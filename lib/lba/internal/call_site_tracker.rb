require_relative "writer"

module Lba
  module Internal
    class CallSiteTracker
      DEFAULT_CAP = 500
      DEFAULT_WINDOW = 60

      class << self
        def current
          @current ||= new.tap { |tracker| tracker.send(:register_at_exit!) }
        end
      end

      def initialize
        @sites = {}
        @global_seq = 0
      end

      def suppressed?(site_key, sink: nil, window: DEFAULT_WINDOW)
        site = site_for(site_key)
        refresh_window!(site_key, site, sink:, window:, now: Process.clock_gettime(Process::CLOCK_MONOTONIC))

        site[:suppressed]
      end

      def record(site_key, sink: nil, cap: DEFAULT_CAP, window: DEFAULT_WINDOW)
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        site = site_for(site_key)
        refresh_window!(site_key, site, sink:, window:, now:)

        return suppress!(site) if site[:suppressed]

        increment!(site)

        return suppress!(site) if over_cap?(site, cap)

        { seq: @global_seq, site_seq: site[:site_seq], diff: advance_diff!(site, now) }
      end

    private

      attr_reader :sites

      def site_for(site_key)
        sites[site_key] ||= {
          site_seq: 0,
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
        site[:site_seq] = 0
        site[:suppressed] = false
        site[:suppressed_count] = 0
      end

      def increment!(site)
        site[:site_seq] += 1
        @global_seq += 1
      end

      def over_cap?(site, cap)
        site[:site_seq] > cap
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

      def register_at_exit!
        at_exit { flush_all! }
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
