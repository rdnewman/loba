require_relative "visits/site_visits"

module Lba
  module Internal
    class Run
      # The run's visits to call sites: numbers records across the process and
      # per call site, and caps how many records one call site writes per
      # window of time. Keeps running counts and times, not the visits
      # themselves; the written records are the history.
      class Visits
        class << self
          # This process's visits. On first use it registers an +at_exit+ hook
          # that writes the count of calls skipped at any capped site, then
          # summarizes records that couldn't be written (see WriteFailures).
          #
          # A forked child inherits this memo; the pid check gives it fresh counters.
          #
          # @return [Visits]
          def current
            return @current if @current&.pid == Process.pid

            @current = new.tap { |visits| visits.send(:register_at_exit) }
          end
        end

        # @return [Integer] the id of the process that created this instance
        attr_reader :pid

        # Starts with no call sites seen.
        def initialize
          @pid = Process.pid
          @site_visits = {}
          @global_seq = 0
          @last_ts_mono_time = nil
        end

        # Counts one call at a site, unless the site is capped for its current
        # window. A capped site skips calls until the window ends; the next call
        # after that writes one record counting the calls skipped, and the site
        # starts a new window with a fresh cap. Skipped calls take no numbers.
        #
        # A site is one record type at one file and line, so a +val+ and a +ts+
        # on the same line are counted and capped separately.
        #
        # @param site [Site] the call site
        # @param destination [Destination, nil] where this site's skipped-call
        #   record goes; +nil+ keeps the site's last destination
        # @param checkpoint [Boolean] whether the call is a checkpoint, timed
        #   from the previous one
        # @return [Hash{Symbol => Integer, Float, nil}, :suppressed] +:suppressed+
        #   if the site is capped; otherwise:
        #   * +:seq+ [Integer] - this record's order among all the process's records
        #   * +:mono_time+ [Float] - the monotonic clock reading that +:diff+ and
        #     +:since_prev_ts+ are measured from, for the record to write, so
        #     they equal the gaps between written +mono_time+ values
        #   * +:site_seq+ [Integer] - its order among the site's records
        #   * +:diff+ [Float, nil] - seconds since the site's previous record, or
        #     +nil+ for its first
        #   * +:since_prev_ts+ [Float, nil] - checkpoints only: seconds since the
        #     process's previous checkpoint at any site, or +nil+ for its first.
        #     Suppression records don't count as a previous checkpoint.
        def record(site, destination: nil, checkpoint: false)
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          # A record counting the site's skipped calls takes its seq, through the
          # block, before this call takes the next one.
          numbered = site_visits_for(site).record_call(now:, destination:) { advance_seq }
          return :suppressed if numbered == :suppressed

          { seq: advance_seq, mono_time: now, **numbered, **checkpoint_fields(checkpoint, now) }
        end

      private

        attr_reader :site_visits

        def site_visits_for(site)
          site_visits[site] ||= SiteVisits.new(site)
        end

        def checkpoint_fields(checkpoint, now)
          if checkpoint
            { since_prev_ts: advance_since_prev_ts(now) }
          else
            {}
          end
        end

        def advance_since_prev_ts(now)
          since_prev_ts = if @last_ts_mono_time
                            now - @last_ts_mono_time
                          end
          @last_ts_mono_time = now
          since_prev_ts
        end

        # Forked children inherit this hook; the pid check keeps them from
        # re-flushing the parent's suppressed sites or repeating its summary.
        def register_at_exit
          at_exit { shut_down if pid == Process.pid }
        end

        # Summarizes write failures only after flushing, so a suppression record
        # that can't be written is counted in the summary rather than lost.
        def shut_down
          flush_all
          WriteFailures.existing&.summarize
        end

        def flush_all
          site_visits.each_value do |visits_at_site|
            visits_at_site.flush { advance_seq }
          end
        end

        def advance_seq
          @global_seq += 1
        end
      end
    end
  end
end
