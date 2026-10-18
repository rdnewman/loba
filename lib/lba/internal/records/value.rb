require_relative "stamp"
require_relative "label"
require_relative "../serialization"
require_relative "caller"

module Lba
  module Internal
    module Records
      # Builds a value record's fields, evaluating the argument in the caller.
      class Value
        # The record type.
        TYPE = "val".freeze

        # Calls aren't checkpoints.
        CHECKPOINT = false

        # The value is the field most likely to be long, so everything that
        # describes it comes first.
        VALUE_FIELDS = [:value_type, :rendered, :cut, :errors, :collided, :value].freeze
        private_constant :VALUE_FIELDS

        # Builds the record's fields; shorthand for +new(...).fields+.
        #
        # @return (see #fields)
        def self.fields(...) = new(...).fields

        # @param caller_binding [CallerBinding] the calling frame
        # @param tracked [Hash{Symbol => Integer, Float, nil}] the call's numbers
        #   and timing (see Run::Visits#note)
        # @param argument [Symbol, Object] the argument given (see Lba.value)
        # @param label [String, Symbol, nil] the label given, if any
        # @param inspect [Boolean] how to render a value with no JSON form
        def initialize(caller_binding:, tracked:, argument:, label:, inspect:)
          @caller_binding = caller_binding
          @tracked = tracked
          @argument = argument
          @label = label
          @inspect = inspect
        end

        # @return [Hash{Symbol => Object}] the record's fields, in order
        def fields
          # Stamped before the value is evaluated, so serializing a large value
          # doesn't delay wall_time.
          stamp = Stamp.fields(mono_time: tracked[:mono_time])
          {
            seq: tracked[:seq],
            type: TYPE,
            label: Label.infer(argument:, label:),
            **Caller.fields(caller_binding),
            site_seq: tracked[:site_seq],
            diff: tracked[:diff],
            **evaluated_fields,
            **stamp
          }
        end

      private

        attr_reader :caller_binding, :tracked, :argument, :label, :inspect

        # Evaluating a Symbol runs the caller's code, which can raise, or fail
        # to compile (a SyntaxError, which is a ScriptError, not a
        # StandardError); that is recorded rather than raised, so tracing never
        # breaks the traced code. Only evaluation is rescued, so lba's own bugs
        # still surface.
        def evaluated_fields
          evaluated = caller_binding.evaluate(argument)
        rescue StandardError, ScriptError => e
          { errors: [{ path: [], message: "#{e.class}: #{e.message}" }] }
        else
          Serialization.serialize(value: evaluated, inspect:).slice(*VALUE_FIELDS)
        end
      end
    end
  end
end
