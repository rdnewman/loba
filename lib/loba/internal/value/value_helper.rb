require 'binding_of_caller'

module Loba
  module Internal
    module Value
      # Internal helper functions for Value.phrases
      module ValueHelper
        module_function

        # Assemble display that shows the method invoking Loba
        # @param depth [Integer] depth in call stack to retrieve tag from
        # @return [String] tag for where Loba was invoked, wrapped in "[" and "]"
        def tag(depth: 0)
          delim = { class: '.', instance: '#' }
          '[' \
            "#{class_name(depth: depth + 1)}" \
            "#{delim[method_type(depth: depth + 1)]}" \
            "#{method_name(depth: depth + 1)}" \
            ']'
        end

        # Identify source code line from where Loba was invoked
        # @param depth [Integer] depth in call stack to retrieve source code line from
        # @return [Integer] source code line number where Loba was invoked
        def line(depth: 0)
          caller[depth]
        end

        # Prepare display of an argument's value.
        # @param argument [Symbol, Object] the value or variable for which information is
        #   to be retrieved
        # @param inspect [Boolean] when true, force #inspect to be called against
        #   +argument+ when evaluating
        # @param depth [Integer] depth in call stack to start evaluation from
        # @return [String] value representation of argument for display
        def value(argument:, inspect: true, depth: 0)
          val = evaluate(argument: argument, inspect: inspect, depth: depth + 1)

          # #inspect adds explicit quotes to strings, so strip back off since #inspect
          # always returns a String
          val = Loba::Internal.unquote(val) if inspect

          # make nils obvious
          val.nil? ? '-nil-' : val.to_s
        end

        # Builds a label for display based on the argument when instantiated.
        # If the argument (when instantiated) is not a symbol, it may not be possible
        # to infer a label; in that case, "[unknown value]"" is returned.
        #
        # @param argument [Symbol, Object] the value or variable for which information is
        #   to be retrieved
        #   * If a symbol, it is assumed to be a reference to a variable
        #     and a label can be inferred.
        #   * If any other type, it is assumed to be a literal value to
        #     and a label should be supplied when instantiated.
        # @param explicit_label [String] when provided, an explicit label to use; will
        #   override any possible inferred label
        #
        # @return [String] label
        def label(argument:, explicit_label: nil)
          text = if explicit_label.nil?
                   argument.is_a?(Symbol) ? "#{argument}:" : nil
                 elsif explicit_label.respond_to?(:strip)
                   s = explicit_label.strip
                   s += ':' unless s[-1] == ':'
                   s
                 end

          text.nil? ? '[unknown value]:' : text.to_s
        end

        # Evaluate an arguments value from where it's bound.
        # @param argument [Symbol, Object] the value or variable for which information is
        #   to be retrieved
        # @param inspect [Boolean] when true, force +#inspect+ to be called against
        #   +argument+ when evaluating
        # @param depth [Integer] depth in call stack to start evaluation from
        # @return [Object] value of the argument when Loba was invoked
        def evaluate(argument:, inspect: true, depth: 0)
          return inspect ? argument.inspect : argument unless argument.is_a?(Symbol)

          evaluation = binding.of_caller(depth + 1).eval(argument.to_s)
          inspect ? evaluation.inspect : evaluation
        end

        # Prepare display of class name from where Loba was invoked
        # @param depth [Integer] depth in call stack to retrieve class name from
        # @return [String] name of class where Loba was invoked
        def class_name(depth: 0)
          m = binding.of_caller(depth + 1).eval('self.class.name')
          if m.nil? || m.empty?
            '<anonymous class>'
          elsif m == 'Class'
            binding.of_caller(depth + 1).eval('self.name')
          else
            m
          end
        end

        # Prepare display of whether the method from where Loba was invoked is
        # for a class or an instance
        # @param depth [Integer] depth in call stack
        # @return [:class] if method in call stack is a class method
        # @return [:instance] if method in call stack is an instance method
        def method_type(depth: 0)
          if binding.of_caller(depth + 1).eval('self.class.name') == 'Class'
            :class
          else
            :instance
          end
        end

        # Prepare display of method name from where Loba was invoked
        # @param depth [Integer] depth in call stack to retrieve method name from
        # @return [Symbol, String] name of class where Loba was invoked
        def method_name(depth: 0)
          m = binding.of_caller(depth + 1).eval('self.send(:__method__)')
          m.nil? || m.empty? ? '<anonymous method>' : m
        end
      end
    end
  end
end
