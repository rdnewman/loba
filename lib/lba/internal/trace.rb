require "json"

module Lba
  module Internal
    # Carries out one +Lba.value+ or +Lba.timestamp+ call: checks it's enabled
    # and not capped, captures the caller, builds the record, and writes it.
    class Trace
      # The frames between the caller and #record: the public method (e.g.
      # +.value+), Trace.record, and #record itself. Depth counts from where the
      # CallerBinding is built, so it must be built directly in #record.
      DEPTH = 3

      # Records one call; shorthand for +new(...).record+.
      #
      # @return (see #record)
      def self.record(...) = new(...).record

      # @param record_class [Class] the record's builder, e.g. Records::Value
      # @param options [Hash] keywords the builder takes beyond the caller and
      #   the tracker's numbers, e.g. +argument:+
      # @param log (see Lba.value)
      # @param logger (see Lba.value)
      # @param sink (see Lba.value)
      def initialize(record_class, options: {}, log: nil, logger: nil, sink: nil)
        @record_class = record_class
        @options = options
        @log = log
        @logger = logger
        @sink = sink
      end

      # Writes the record to the sink, and to the logger if logging. Does
      # nothing in a production environment, or once this call site is capped.
      #
      # @return [void]
      def record
        return if settings.disabled?

        @caller_binding = CallerBinding.new(depth: DEPTH)
        @tracked = track
        return if tracked == :suppressed

        write(
          record_class.fields(caller_binding:, tracked:, **options)
        )

        nil
      end

    private

      attr_reader :record_class, :options, :log, :logger, :sink, :caller_binding, :tracked

      def track
        Tracker.current.record(site, sink: settings.sink, checkpoint: record_class::CHECKPOINT)
      end

      def site
        Site.new(type: record_class::TYPE, file: caller_binding.file, line: caller_binding.line)
      end

      def write(fields)
        Writer.write(fields, sink: settings.sink)
        settings.logger&.debug(JSON.generate(fields))
      end

      def settings
        @settings ||= Settings.new(log:, logger:, sink:)
      end
    end
  end
end
