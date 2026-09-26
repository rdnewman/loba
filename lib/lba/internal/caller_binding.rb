require "debug_inspector"

module Lba
  module Internal
    class CallerBinding
      # Skips the .open block and #initialize to reach whoever called .new.
      FRAME_OFFSET = 2

      # Each .open snapshots the whole stack, costing time in proportion to its
      # depth, so everything is read from the frame in one open.
      def initialize(depth: 0)
        RubyVM::DebugInspector.open do |context|
          frame = depth + FRAME_OFFSET
          @location = context.backtrace_locations[frame]
          @frame_self = context.frame_self(frame)
          @frame_binding = context.frame_binding(frame)
        end
      end

      def class_name
        value = if module_self?
                  frame_self.name
                else
                  class_of_frame_self.name
                end

        if value.nil? || value.empty?
          "<anonymous class>"
        else
          value
        end
      end

      def method_type
        if module_self?
          :class
        else
          :instance
        end
      end

      def method_name
        value = frame_binding.eval("__method__")

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

        frame_binding.eval(argument.to_s)
      end

    private

      attr_reader :location, :frame_self, :frame_binding

      # Module#=== and Kernel#class via bind_call also work on a BasicObject,
      # which has neither #is_a? nor #class of its own.
      def module_self?
        ::Module === frame_self # rubocop:disable Style/CaseEquality -- see above
      end

      def class_of_frame_self
        ::Kernel.instance_method(:class).bind_call(frame_self)
      end
    end
  end
end
