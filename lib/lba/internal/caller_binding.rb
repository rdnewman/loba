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
        target = RubyVM::DebugInspector.open { |dc| dc.frame_self(depth + FRAME_OFFSET) }
        return target.name if target.instance_of?(::Class)

        value = target.class.name
        if value.nil? || value.empty?
          "<anonymous class>"
        else
          value
        end
      end

      def method_type
        target = RubyVM::DebugInspector.open { |dc| dc.frame_self(depth + FRAME_OFFSET) }
        if target.instance_of?(::Class)
          :class
        else
          :instance
        end
      end

      def method_name
        value = RubyVM::DebugInspector.open do |dc|
          dc.frame_binding(depth + FRAME_OFFSET).eval("__method__")
        end

        if value.nil? || value.empty?
          "<anonymous method>"
        else
          value
        end
      end

      def source_line
        RubyVM::DebugInspector.open { |dc| dc.backtrace_locations[depth + FRAME_OFFSET] }.to_s
      end

      def evaluate(argument)
        RubyVM::DebugInspector.open do |dc|
          dc.frame_binding(depth + FRAME_OFFSET).eval(argument.to_s)
        end
      end

    private

      attr_reader :depth
    end
  end
end
