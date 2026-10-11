require_relative "../record_stamp"
require_relative "../label"
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

        # Builds the record's fields; shorthand for +new(...).fields+.
        #
        # @return (see #fields)
        def self.fields(...) = new(...).fields

        # @param caller_binding [CallerBinding] the calling frame
        # @param tracked [Hash{Symbol => Integer, Float, nil}] the call's numbers
        #   and timing (see Tracker#record)
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
          {
            **RecordStamp.fields(seq: tracked[:seq], type: TYPE, mono_time: tracked[:mono_time]),
            site_seq: tracked[:site_seq],
            diff: tracked[:diff],
            **Caller.fields(caller_binding),
            label: Label.infer(argument:, label:),
            **evaluated_fields
          }
        end

      private

        attr_reader :caller_binding, :tracked, :argument, :label, :inspect

        # Evaluating a Symbol runs the caller's code, which can raise; that is
        # recorded rather than raised, so tracing never breaks the traced code.
        # Only evaluation is rescued, so lba's own bugs still surface.
        def evaluated_fields
          evaluated = caller_binding.evaluate(argument)
        rescue StandardError => e
          { errors: [{ path: [], message: "#{e.class}: #{e.message}" }] }
        else
          Serialization.serialize(value: evaluated, inspect:)
        end
      end
    end
  end
end
