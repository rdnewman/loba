require 'binding_of_caller'

module Loba
  module Internal
    module Value
    module_function

      # Retrieve a value used in code.
      #
      # @param argument [Symbol, Object] the value or variable for which information is
      #   to be retrieved
      #   * If a symbol, it is assumed to be a reference to a variable
      #     and a label can be inferred.
      #   * If any other type, it is assumed to be a literal value to
      #     and a label should be supplied when instantiated.
      # @param label [String] an explicit label to use; will override any possible inferred label
      # @param inspection [Boolean] force #inspect to be called against `argument` when evaluating
      #
      # @return [Hash] various detail about the value being analyzed
      #   * :tag => [String] method name (wrapped in square brackets)
      #   * :line => [String] code line reference
      #   * :value => [String] value of argument (if nil, '-nil-' is returned)
      #   * :label => [String] label, ending with ":"
      #     (if not possible to infer, '[unknown value]' is returned)
      def phrases(argument, label = nil, inspection = true, depth_offset = 0)
        depth = depth_offset&.to_i || 0
        {
          tag: ValueSupport.tag(depth + 1),
          line: ValueSupport.source_line(depth + 1),
          value: ValueSupport.value(argument, inspection, depth + 1),
          label: ValueSupport.label(argument, label)
        }
      end

      module ValueSupport
      module_function

        # Builds a label for display based on the argument when instantiated.
        # If the argument (when instantiated) is not a symbol, it may not be possible
        # to infer a label; in that case, '[unknown value]' is returned.
        #
        # @return [String] label
        def label(argument, supplied_label = nil)
          text = if supplied_label.nil?
                   argument.is_a?(Symbol) ? "#{argument}:" : nil
                 else
                   s = supplied_label.strip
                   s += ':' unless s[-1] == ':'
                   s
                 end

          text.nil? ? '[unknown value]:' : text.to_s
        end

        def value(argument, want_inspection = true, depth = 0)
          val = retrieve_value(argument, want_inspection, depth + 1)

          # #inspect adds explicit quotes to strings, so strip back off since this
          # always returns a String
          if want_inspection && val.respond_to?(:delete_prefix)
            val = val.delete_prefix('"').delete_suffix('"')
          end

          # make nils obvious
          val.nil? ? '-nil-' : val.to_s
        end

        def retrieve_value(argument, want_inspection = true, depth = 0)
          return want_inspection ? argument.inspect : argument unless argument.is_a?(Symbol)

          evaluation = binding.of_caller(depth + 1).eval(argument.to_s)
          want_inspection ? evaluation.inspect : evaluation
        end

        # Assemble display that shows the method invoking Loba
        # @param depth [integer] internal tracking of call stack depth
        def tag(depth = 0)
          delim = { class: '.', instance: '#' }
          '[' \
            "#{class_name(depth + 1)}" \
            "#{delim[method_type(depth + 1)]}" \
            "#{method_name(depth + 1)}" \
            ']'
        end

        # Prepare display of class name from where Loba was invoked
        # @param depth [integer] internal tracking of call stack depth
        def class_name(depth = 0)
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
        # @param depth [integer] internal tracking of call stack depth
        def method_type(depth = 0)
          if binding.of_caller(depth + 1).eval('self.class.name') == 'Class'
            :class
          else
            :instance
          end
        end

        # Prepare display of method name from where Loba was invoked
        # @param depth [integer] internal tracking of call stack depth
        def method_name(depth = 0)
          m = binding.of_caller(depth + 1).eval('self.send(:__method__)')
          m.nil? || m.empty? ? '<anonymous method>' : m
        end

        # Identify source code line from where Loba was invoked
        # @param depth [integer] internal tracking of call stack depth
        def source_line(depth = 0)
          caller[depth]
        end
      end
    end
  end
end
