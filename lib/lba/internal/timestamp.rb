require "json"

module Lba
  module Internal
    # Carries out one +Lba.timestamp+ call: checks it's enabled and not capped,
    # captures the caller, and writes the checkpoint record.
    class Timestamp
      # The frames between the caller and #record: .timestamp, Timestamp.record, and
      # #record itself. Depth counts from where the CallerBinding is built, so
      # it must be built directly in #record.
      DEPTH = 3

      # Records one checkpoint; shorthand for +new(...).record+.
      #
      # @return (see #record)
      def self.record(...) = new(...).record

      # @param (see Lba.timestamp)
      def initialize(label: nil, log: nil, logger: nil, sink: nil)
        @label = label
        @log = log
        @logger = logger
        @sink = sink
      end

      # Writes the record to the sink, and to the logger if logging. Does
      # nothing inside Rails production, or once this call site is capped.
      #
      # @return [void]
      def record
        return if settings.disabled?

        @caller_binding = CallerBinding.new(depth: DEPTH)
        @tracked = track
        return if tracked == :suppressed

        write(build_record)

        nil
      end

    private

      attr_reader :label, :log, :logger, :sink, :caller_binding, :tracked

      def track
        CallSiteTracker.current.record(
          type: Records::Timestamp::TYPE, file: caller_binding.file, line: caller_binding.line,
          sink: settings.sink
        )
      end

      def write(full_record)
        Writer.write(full_record, sink: settings.sink)
        settings.logger&.debug(JSON.generate(full_record))
      end

      def settings
        @settings ||= Settings.new(log:, logger:, sink:)
      end

      def build_record
        Records::Timestamp.new(caller_binding:, tracked:, label:).fields
      end
    end
  end
end
