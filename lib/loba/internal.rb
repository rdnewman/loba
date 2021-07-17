require 'singleton'
require 'binding_of_caller'

module Loba
  module Internal
    class << self
      # Prepare display of class name from where Loba was invoked
      # @param depth [integer] internal tracking of call stack depth
      def calling_class_name(depth = 0)
        m = binding.of_caller(depth + 1).eval('self.class.name')
        if m.nil? || m.empty?
          '<anonymous class>'
        elsif m == 'Class'
          binding.of_caller(depth + 1).eval('self.name')
        else
          m
        end
      end

      # Prepare display of method name from where Loba was invoked
      # @param depth [integer] internal tracking of call stack depth
      def calling_method_name(depth = 0)
        m = binding.of_caller(depth + 1).eval('self.send(:__method__)')
        m.nil? || m.empty? ? '<anonymous method>' : m
      end

      # Prepare display of whether the method from where Loba was invoked is
      # for a class or an instance
      # @param depth [integer] internal tracking of call stack depth
      def calling_method_type(depth = 0)
        if binding.of_caller(depth + 1).eval('self.class.name') == 'Class'
          :class
        else
          :instance
        end
      end

      # Prepare display of line number from where Loba was invoked [UNUSED]
      # @param depth [integer] internal tracking of call stack depth
      def calling_line_number(depth = 0)
        binding.of_caller(depth + 1).eval('__LINE__')
      end

      # Assemble display that shows the method invoking Loba
      # @param depth [integer] internal tracking of call stack depth
      def calling_tag(depth = 0)
        delim = { class: '.', instance: '#' }
        '[' \
          "#{calling_class_name(depth + 1)}" \
          "#{delim[calling_method_type(depth + 1)]}" \
          "#{calling_method_name(depth + 1)}" \
          ']'
      end

      # Identify source code line from where Loba was invoked
      # @param depth [integer] internal tracking of call stack depth
      def calling_source_line(depth = 0)
        caller[depth]
      end

      # Filters options argument for supported values
      # @param options [various] options argument to filter
      # @param allowed_keys [array] array of expected keys in options
      def filter_options(options, allowed_keys = [])
        result = {}
        allowed_keys.each { |key| result[key] = false }

        case options
        when Hash
          allowed_keys.each do |key|
            result[key] = !!options[key] unless options[key].nil?
          end
        when TrueClass, FalseClass
          raise ArgumentError, 'boolean values not supported as options argument; use a hash'
        end

        result
      end
    end

    # Internal class for tracking time stamps; should not be used directly
    # @!attribute [rw] timewas
    #   Previous timestamped Time value
    # @!attribute [rw] timenum
    #   Count of timestamping occurances so far
    class TimeKeeper
      include Singleton
      attr_accessor :timewas, :timenum

      def initialize
        @timewas = Time.now
        @timenum = 0
      end
    end

    # Internal class for managing logging across Rails and non-Rails applications
    class Platform
      class << self
        # Returns true if Rails appears to be available
        def rails?
          defined?(Rails)
        end

        # Returns true if logging is to be allowed
        def logging_ok?(force_true = false)
          return true if force_true
          return true unless rails?

          begin
            !Rails.env.production?
          rescue StandardError
            true # not Rails production if Rails isn't recognized
          end
        end

        # Returns a logging mechanism appropriate for the application
        def logger
          if rails? && Rails.logger.present?
            ->(arg) { Rails.logger.debug arg }
          else
            ->(arg) { puts arg }
          end
        end
      end
    end
  end
end
