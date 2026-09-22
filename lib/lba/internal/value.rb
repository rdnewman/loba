require "json"

module Lba
  module Internal
    class Value
      # .val -> Internal::Value.record -> Internal::Value#record, three frames
      # of lba's own machinery between here and the real caller. Every
      # caller_binding public method call below must happen directly inside
      # #record, at this same nesting level -- depth is measured from
      # wherever the call actually occurs, not from where the CallerBinding
      # instance was constructed, so calling from a nested helper instead
      # would silently point at the wrong frame.
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

      # rubocop:disable-next Metrics/AbcSize -- every caller_binding call
      # here has to stay inline at this exact nesting level (see DEPTH's
      # comment above); extracting any of them into a helper would put that
      # call one frame further from the real caller and silently break it.
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
