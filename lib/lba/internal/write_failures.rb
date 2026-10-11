module Lba
  module Internal
    # Keeps track of records that couldn't be written, so a dropped record
    # isn't mistaken for code that never ran. The first failure is reported on
    # $stderr; each sink's unwritten records are then noted on the next record
    # written there (see #unwritten), or summarized at exit if none is.
    class WriteFailures
      class << self
        # This process's instance, created on first use, which only a write
        # failure triggers. Creating it registers the exit summary.
        #
        # A forked child inherits this memo; the pid check gives it its own,
        # so it reports its own failures.
        #
        # @return [WriteFailures]
        def current
          return @current if @current&.pid == Process.pid

          @current = new.tap { |failures| failures.send(:register_at_exit!) }
        end

        # This process's instance if a failure has created one, without
        # creating it, so a successful write costs almost nothing.
        #
        # @return [WriteFailures, nil]
        def existing
          @current if @current&.pid == Process.pid
        end
      end

      # @return [Integer] the id of the process that created this instance
      attr_reader :pid

      # Starts with no failure reported.
      def initialize
        @pid = Process.pid
        @reported = false
        @unwritten = {}
      end

      # Counts a record that couldn't be written to +sink+, and warns on
      # $stderr about the first such failure in the process.
      #
      # @param sink [IO, String] where the record was to be written
      # @param error [Exception] why it couldn't be
      # @param seq [Integer, nil] the record's +seq+
      # @return [void]
      def report(sink:, error:, seq:)
        count_unwritten(sink, error, seq)
        warn_once(sink, error)
      end

      # The records +sink+ hasn't received since they were last forgotten. They
      # stay until #forget_unwritten, so a write that fails again doesn't lose
      # them.
      #
      # @param sink [IO, String] the sink about to be written
      # @return [Hash{Symbol => Integer, String}, nil] +nil+ if none were
      #   missed; otherwise:
      #   * +:count+ [Integer] - how many records couldn't be written
      #   * +:first_seq+, +:last_seq+ [Integer] - the +seq+ range they fell in
      #   * +:error+ [String] - the first failure, as +"Class: message"+
      def unwritten(sink)
        @unwritten[sink]
      end

      # Forgets +sink+'s unwritten records, once a record that notes them has
      # been written there.
      #
      # @param sink [IO, String] the sink just written
      # @return [void]
      def forget_unwritten(sink)
        @unwritten.delete(sink)
      end

    private

      def count_unwritten(sink, error, seq)
        entry = @unwritten[sink] ||= { count: 0, first_seq: seq, last_seq: seq,
                                       error: "#{error.class}: #{error.message}" }
        entry[:count] += 1
        entry[:last_seq] = seq
      end

      def warn_once(sink, error)
        return if @reported

        @reported = true
        warn "lba: couldn't write a record to #{sink.inspect} " \
             "(#{error.class}: #{error.message}); " \
             "later write failures in this process won't be reported"
      end

      # Forked children inherit this hook; the pid check keeps them from
      # repeating the parent's summary.
      def register_at_exit!
        at_exit { summarize if pid == Process.pid }
      end

      def summarize
        @unwritten.each do |sink, entry|
          warn "lba: #{records(entry[:count])} couldn't be written to #{sink.inspect} " \
               "(first error: #{entry[:error]})"
        end
      end

      def records(count)
        if count == 1
          "1 record"
        else
          "#{count} records"
        end
      end
    end
  end
end
