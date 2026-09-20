require "debug_inspector"

module Lba
  module Internal
    class CallerBinding
      # .open + this method's own frame, to reach the caller of a public method below
      FRAME_OFFSET = 2

      def initialize(depth: 0)
        @depth = depth
      end

      def class_name
        target = frame_self
        value = if target.instance_of?(::Class)
                  target.name
                else
                  target.class.name
                end

        if value.nil? || value.empty?
          "<anonymous class>"
        else
          value
        end
      end

      def method_type
        target = frame_self
        if target.instance_of?(::Class)
          :class
        else
          :instance
        end
      end

      def method_name
        value = frame_binding_eval("__method__")

        if value.nil? || value.empty?
          "<anonymous method>"
        else
          value
        end
      end

      def source_line
        location.to_s
      end

      def file
        location.path
      end

      def line
        location.lineno
      end

      def evaluate(argument)
        return argument unless argument.is_a?(Symbol)

        frame_binding_eval(argument.to_s)
      end

    private

      attr_reader :depth

      # Each of these helpers is itself one extra frame beyond FRAME_OFFSET's
      # baseline (a direct .open call) -- the +1 is local to each helper
      # because that's where the extra frame actually comes from, not a
      # property of FRAME_OFFSET itself.
      def location
        RubyVM::DebugInspector.open { |dc| dc.backtrace_locations[depth + FRAME_OFFSET + 1] }
      end

      def frame_self
        RubyVM::DebugInspector.open { |dc| dc.frame_self(depth + FRAME_OFFSET + 1) }
      end

      def frame_binding_eval(string)
        RubyVM::DebugInspector.open do |dc|
          dc.frame_binding(depth + FRAME_OFFSET + 1).eval(string)
        end
      end
    end
  end
end
