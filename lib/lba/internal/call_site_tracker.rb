require_relative "call_site_tracker/site"

module Lba
  module Internal
    # Numbers records across the process and per call site, and caps how many
    # records one call site writes per window of time.
    class CallSiteTracker
      # Records one call site may write per window.
      CAP = 500

      # Length of a window, in seconds.
      WINDOW = 60

      private_constant :CAP, :WINDOW

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
      # @param type [String] the kind of record, e.g. +"val"+
      # @param file [String] the calling file
      # @param line [Integer] the calling line
      # @param sink [IO, String, nil] where this site's skipped-call record goes
      # @return [Hash{Symbol => Integer, Float, nil}, :suppressed] +:suppressed+
      #   if the site is capped; otherwise:
      #   * +:seq+ [Integer] - this record's order among all the process's records
      #   * +:mono_time+ [Float] - the monotonic clock reading that +:diff+ and
      #     +:since_prev_ts+ are measured from, for the record to write, so
      #     they equal the gaps between written +mono_time+ values
      #   * +:site_seq+ [Integer] - its order among the site's records
      #   * +:diff+ [Float, nil] - seconds since the site's previous record, or
      #     +nil+ for its first
      #   * +:since_prev_ts+ [Float, nil] - +ts+ only: seconds since the
      #     process's previous +ts+ record at any site, or +nil+ for its first.
      #     Suppression records don't count as a previous +ts+.
      def record(type:, file:, line:, sink: nil)
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        site = site_for(type:, file:, line:)
        # A record counting the site's skipped calls takes its seq, through the
        # block, before this call takes the next one.
        numbered = site.record_call(now:, cap: CAP, window_length: WINDOW, sink:) { next_seq! }
        return :suppressed if numbered == :suppressed

        { seq: next_seq!, mono_time: now, **numbered, **checkpoint_fields(type, now) }
      end

    private

      attr_reader :sites

      def site_for(type:, file:, line:)
        sites[[type, file, line]] ||= Site.new(type:, file:, line:)
      end

      def checkpoint_fields(type, now)
        if type == "ts"
          { since_prev_ts: advance_since_prev_ts!(now) }
        else
          {}
        end
      end

      def advance_since_prev_ts!(now)
        since_prev_ts = if @last_ts_mono_time
                          now - @last_ts_mono_time
                        end
        @last_ts_mono_time = now
        since_prev_ts
      end

      # Forked children inherit this hook; the pid check keeps them from
      # re-flushing the parent's suppressed sites.
      def register_at_exit!
        at_exit { flush_all! if pid == Process.pid }
      end

      def flush_all!
        sites.each_value do |site|
          site.flush { next_seq! }
        end
      end

      def next_seq!
        @global_seq += 1
      end
    end
  end
end
