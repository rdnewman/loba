require "debug_inspector"

module Lba
  module Internal
    class CallerBinding
      # Skips the .open block and #initialize to reach whoever called .new.
      FRAME_OFFSET = 2

      # Binding#local_variable_defined? raises for anything not shaped like a
      # local name, such as :valid? or :Foo, so only these names are checked.
      LOCAL_NAME = /\A[[:lower:]_][[:alnum:]_]*\z/
      INSTANCE_VARIABLE_NAME = /\A@[[:alpha:]_][[:alnum:]_]*\z/
      private_constant :LOCAL_NAME, :INSTANCE_VARIABLE_NAME

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

      # Locals and instance variables, the common cases, are read directly;
      # Binding#eval compiles a string on every call and costs far more.
      # Anything else (methods, constants, globals) still goes through eval.
      def evaluate(argument)
        return argument unless argument.is_a?(Symbol)

        if instance_variable_name?(argument)
          instance_variable_of_frame_self(argument)
        elsif local_variable?(argument)
          frame_binding.local_variable_get(argument)
        else
          frame_binding.eval(argument.to_s)
        end
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

      def instance_variable_of_frame_self(name)
        ::Kernel.instance_method(:instance_variable_get).bind_call(frame_self, name)
      end

      def instance_variable_name?(argument)
        argument.match?(INSTANCE_VARIABLE_NAME)
      end

      def local_variable?(argument)
        argument.match?(LOCAL_NAME) && frame_binding.local_variable_defined?(argument)
      end
    end
  end
end
