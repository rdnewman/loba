require 'binding_of_caller'
require_relative 'internal/platform'
require_relative 'internal/time_keeper'

module Loba
  module Internal
    # Prepare display of class name from where Loba was invoked
    # @param depth [integer] internal tracking of call stack depth
    def self.calling_class_name(depth = 0)
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
    def self.calling_method_name(depth = 0)
      m = binding.of_caller(depth + 1).eval('self.send(:__method__)')
      m.nil? || m.empty? ? '<anonymous method>' : m
    end

    # Prepare display of whether the method from where Loba was invoked is
    # for a class or an instance
    # @param depth [integer] internal tracking of call stack depth
    def self.calling_method_type(depth = 0)
      if binding.of_caller(depth + 1).eval('self.class.name') == 'Class'
        :class
      else
        :instance
      end
    end

    # Prepare display of line number from where Loba was invoked [UNUSED]
    # @param depth [integer] internal tracking of call stack depth
    def self.calling_line_number(depth = 0)
      binding.of_caller(depth + 1).eval('__LINE__')
    end

    # Assemble display that shows the method invoking Loba
    # @param depth [integer] internal tracking of call stack depth
    def self.calling_tag(depth = 0)
      delim = { class: '.', instance: '#' }
      '[' \
        "#{calling_class_name(depth + 1)}" \
        "#{delim[calling_method_type(depth + 1)]}" \
        "#{calling_method_name(depth + 1)}" \
        ']'
    end

    # Identify source code line from where Loba was invoked
    # @param depth [integer] internal tracking of call stack depth
    def self.calling_source_line(depth = 0)
      caller[depth]
    end

    # Filters options argument for supported values
    # @param options [various] options argument to filter
    # @param allowed_keys [array] array of expected keys in options
    def self.filter_options(options, allowed_keys = [])
      # last check against old style now that it's fully obsolete
      # FUTURE: drop this check after the next version
      if options.is_a?(TrueClass) || options.is_a?(FalseClass)
        raise ArgumentError, 'boolean values not supported as options argument; use a hash'
      end

      # allowed keys are always there and default to false
      default = allowed_keys.each_with_object({}) { |key, hash| hash[key] = false }

      # abort with that default result if given options aren't usuable
      return default unless options.is_a?(Hash)

      # ensure given options have boolean values and return the result
      allowed_keys.each_with_object(default) do |key, result|
        result[key] = !!options[key] unless options[key].nil?
      end
    end
  end
end
