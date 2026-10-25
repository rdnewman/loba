require "debug_inspector"

module Loba
  module Internal
    # A snapshot of one frame on the call stack: where it is, who +self+ is
    # there, and its binding, for reading the caller's values.
    class CallerBinding
      # Skips DebugInspector.open's own frame and .capture to reach whoever
      # called .capture. The snapshot is taken there, not in #initialize, so
      # Class#new, which adds a frame of its own on Ruby 3.3 and 3.4, is never
      # between it and the caller.
      FRAME_OFFSET = 2

      # Binding#local_variable_defined? raises for anything not shaped like a
      # local name, such as :valid? or :Foo, so only these names are checked.
      LOCAL_NAME = /\A[[:lower:]_][[:alnum:]_]*\z/
      INSTANCE_VARIABLE_NAME = /\A@[[:alpha:]_][[:alnum:]_]*\z/
      private_constant :LOCAL_NAME, :INSTANCE_VARIABLE_NAME

      # Takes the snapshot of the frame that called +.capture+, or of a frame
      # above it. Capture it directly in the frame to describe: depth counts
      # from there.
      #
      # Each .open snapshots the whole stack, costing time in proportion to its
      # depth, so everything is read from the frame in one open.
      #
      # @param depth [Integer] how many frames above the caller of +.capture+
      #   to describe; +0+ describes that caller itself
      # @return [CallerBinding]
      def self.capture(depth: 0)
        RubyVM::DebugInspector.open do |context|
          frame = depth + FRAME_OFFSET
          location = context.backtrace_locations[frame]
          frame_self = context.frame_self(frame)
          frame_binding = context.frame_binding(frame)
          new(location:, frame_self:, frame_binding:)
        end
      end

      private_class_method :new

      def initialize(location:, frame_self:, frame_binding:)
        @location = location
        @frame_self = frame_self
        @frame_binding = frame_binding
      end

      # @return [String] the frame's class, or the class or module itself inside
      #   a class or module method; +"<anonymous class>"+ if it has no name
      def class_name
        value = name_of(frame_module)

        if value.nil? || value.empty?
          "<anonymous class>"
        else
          value
        end
      end

      # @return [Symbol] +:class+ inside a class or module method; otherwise
      #   +:instance+
      def method_type
        if module_self?
          :class
        else
          :instance
        end
      end

      # @return [Symbol, String] the frame's method, including the method that
      #   encloses a block or lambda; +"<anonymous method>"+ outside any method
      def method_name
        value = frame_binding.eval("__method__")

        if value.nil? || value.empty?
          "<anonymous method>"
        else
          value
        end
      end

      # @return [String] the frame's location in +caller+ format, starting
      #   +"path:line:in "+
      def source_line
        location.to_s
      end

      # @return [String] the path of the frame's source file
      def file
        location.path
      end

      # @return [Integer] the frame's line number
      def line
        location.lineno
      end

      # Reads a value in the frame, the way code there would.
      #
      # Locals and instance variables, the common cases, are read directly;
      # Binding#eval compiles a string on every call and costs far more.
      # Anything else (methods, constants, globals) still goes through eval.
      #
      # @param argument [Symbol, Object] a +Symbol+ naming a local, instance
      #   variable, method, constant, global, or expression in the frame;
      #   anything else is returned as given
      # @return [Object] the named value, or +argument+ itself if it isn't a
      #   +Symbol+
      # @raise [NameError] if a +Symbol+ names nothing in the frame
      # @raise [SyntaxError] if a +Symbol+ isn't valid Ruby, e.g. +:"1abc"+
      # @raise [StandardError] whatever a method named by +argument+ raises
      def evaluate(argument)
        # Module#=== rather than #is_a?, which a BasicObject argument lacks.
        return argument unless Symbol === argument # rubocop:disable Style/CaseEquality

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

      def frame_module
        if module_self?
          frame_self
        else
          class_of_frame_self
        end
      end

      # A class's own name method comes first, since it can name an anonymous
      # class (as specs often do); it runs the traced program's code, so if it
      # raises or returns something other than a String, the constant's name
      # is used.
      def name_of(mod)
        given = mod.name

        if ::String === given # rubocop:disable Style/CaseEquality -- see module_self?
          given
        else
          constant_name_of(mod)
        end
      rescue StandardError
        constant_name_of(mod)
      end

      def constant_name_of(mod) = ::Module.instance_method(:name).bind_call(mod)

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
