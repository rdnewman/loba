module Lba
  module Internal
    # Carries out one +Lba.value+ or +Lba.timestamp+ call: checks it's enabled
    # and not capped, captures the caller, builds the record, and writes it.
    class Invocation
      # The frames between the caller and #record: the public method (e.g.
      # +.value+), Invocation.record, and #record itself. Depth counts from where the
      # CallerBinding is captured, so it must be captured directly in #record.
      DEPTH = 3

      # Records one call; shorthand for +new(...).record+.
      #
      # @return (see #record)
      def self.record(...) = new(...).record

      # @param record_class [Class] the record's builder, e.g. Records::Value
      # @param options [Hash] keywords the builder takes beyond the caller and
      #   the visit's numbers, e.g. +argument:+
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
        return if Platform::Environment.production?

        @destination = Destination.for(sink:, log:, logger:)
        @caller_binding = CallerBinding.capture(depth: DEPTH)
        @tracked = track
        return if tracked == :suppressed

        destination.write(record_class.fields(caller_binding:, tracked:, **options))

        nil
      end

    private

      attr_reader :record_class, :options, :log, :logger, :sink,
                  :destination, :caller_binding, :tracked

      def track
        visits.note(site, destination:, checkpoint: record_class::CHECKPOINT)
      end

      def visits = Run.current.visits

      def site
        Site.new(type: record_class::TYPE, file: caller_binding.file, line: caller_binding.line)
      end
    end
  end
end
