require "json"

module Lba
  module Internal
    class Value
      # The frames between the caller and #record: .val, Value.record, and
      # #record itself. Depth counts from where caller_binding is called, not
      # where it was built, so every call must sit directly in #record.
      DEPTH = 3

      def self.record(...) = new(...).record

      # rubocop:disable-next Metrics/ParameterLists -- matches Lba.val's public kwarg surface
      def initialize(argument, label: nil, inspect: true, log: nil, logger: nil, sink: nil)
        @argument = argument
        @label = label
        @inspect = inspect
        @log = log
        @logger = logger
        @sink = sink
      end

      # rubocop:disable-next Metrics/AbcSize -- caller_binding calls must stay
      # inline here (see DEPTH); a helper would add a frame and read the wrong one.
      def record
        return if settings.disabled?

        @file = caller_binding.file
        @line = caller_binding.line
        @tracked = CallSiteTracker.current.record("#{file}:#{line}", sink: resolved_sink)
        return if tracked == :suppressed

        @evaluated = caller_binding.evaluate(argument)
        @class_name = caller_binding.class_name
        @method_name = caller_binding.method_name
        @method_type = caller_binding.method_type

        full_record = build_record
        Writer.write(full_record, sink: resolved_sink)
        settings.logger&.debug(JSON.generate(full_record))

        nil
      end

    private

      attr_reader :argument, :label, :inspect, :log, :logger, :sink,
                  :file, :line, :tracked, :evaluated, :class_name, :method_name, :method_type

      def settings
        @settings ||= Settings.new(log:, logger:)
      end

      def caller_binding
        @caller_binding ||= CallerBinding.new(depth: DEPTH)
      end

      def resolved_sink
        @resolved_sink ||= SinkResolver.resolve(sink:)
      end

      def build_record
        { **common_fields, **value_fields }
      end

      def common_fields
        {
          schema: 1,
          run_id: Run.current.id,
          seq: tracked[:seq],
          site_seq: tracked[:site_seq],
          type: "val",
          wall_time: Time.now.to_f,
          mono_time: Process.clock_gettime(Process::CLOCK_MONOTONIC),
          diff: tracked[:diff],
          file:,
          line:,
          class_name:,
          method_name:,
          method_type:
        }
      end

      def value_fields
        {
          label: Label.infer(argument:, label:),
          **Serialization.serialize(value: evaluated, inspect:)
        }
      end
    end
  end
end
