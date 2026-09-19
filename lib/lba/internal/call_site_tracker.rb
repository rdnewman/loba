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
        refresh_window!(site_key, site, sink:, window:)

        site[:suppressed]
      end

      def record(site_key, value:, sink: nil, cap: DEFAULT_CAP, window: DEFAULT_WINDOW)
        site = site_for(site_key)
        refresh_window!(site_key, site, sink:, window:)

        return suppress!(site) if site[:suppressed]

        site[:site_seq] += 1
        @global_seq += 1

        return suppress!(site) if site[:site_seq] > cap

        changed = !site[:value_seen] || value != site[:last_value]
        prev_value = site[:last_value]
        site[:last_value] = value
        site[:value_seen] = true

        { seq: @global_seq, site_seq: site[:site_seq], changed:, prev_value: }
      end

    private

      attr_reader :sites

      def site_for(site_key)
        sites[site_key] ||= {
          site_seq: 0,
          last_value: nil,
          value_seen: false,
          window_start: nil,
          suppressed: false,
          suppressed_count: 0
        }
      end

      def refresh_window!(site_key, site, sink:, window:)
        site[:sink] = sink if sink

        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        site[:window_start] ||= now

        return if now - site[:window_start] < window

        flush!(site_key, site, sink:) if site[:suppressed]

        site[:window_start] = now
        site[:site_seq] = 0
        site[:suppressed] = false
        site[:suppressed_count] = 0
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
