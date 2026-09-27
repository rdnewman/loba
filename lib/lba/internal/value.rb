require "json"

module Lba
  module Internal
    # Carries out one +Lba.val+ call: checks it's enabled and not capped,
    # captures the caller and the value, and writes the record.
    class Value
      # The frames between the caller and #record: .val, Value.record, and
      # #record itself. Depth counts from where the CallerBinding is built, so
      # it must be built directly in #record.
      DEPTH = 3

      # Records one value; shorthand for +new(...).record+.
      #
      # @return (see #record)
      def self.record(...) = new(...).record

      # rubocop:disable Metrics/ParameterLists -- matches Lba.val's public kwarg surface

      # @param (see Lba.val)
      def initialize(argument, label: nil, inspect: true, log: nil, logger: nil, sink: nil)
        @argument = argument
        @label = label
        @inspect = inspect
        @log = log
        @logger = logger
        @sink = sink
      end
      # rubocop:enable Metrics/ParameterLists

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

      attr_reader :argument, :label, :inspect, :log, :logger, :sink, :caller_binding, :tracked

      def track
        CallSiteTracker.current.record(
          type: "val", file: caller_binding.file, line: caller_binding.line, sink: resolved_sink
        )
      end

      def write(full_record)
        Writer.write(full_record, sink: resolved_sink)
        settings.logger&.debug(JSON.generate(full_record))
      end

      def settings
        @settings ||= Settings.new(log:, logger:)
      end

      def resolved_sink
        @resolved_sink ||= SinkResolver.resolve(sink:)
      end

      def build_record
        { **common_fields, **caller_fields, **value_fields }
      end

      def common_fields
        {
          **RecordStamp.fields(seq: tracked[:seq], type: "val"),
          site_seq: tracked[:site_seq],
          diff: tracked[:diff]
        }
      end

      def caller_fields
        {
          file: caller_binding.file,
          line: caller_binding.line,
          class_name: caller_binding.class_name,
          method_name: caller_binding.method_name,
          method_type: caller_binding.method_type
        }
      end

      def value_fields
        { label: Label.infer(argument:, label:), **evaluated_fields }
      end

      # Evaluating a Symbol runs the caller's code, which can raise; that is
      # recorded rather than raised, so tracing never breaks the traced code.
      # Only evaluation is rescued, so lba's own bugs still surface.
      def evaluated_fields
        evaluated = caller_binding.evaluate(argument)
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      else
        Serialization.serialize(value: evaluated, inspect:)
      end
    end
  end
end
