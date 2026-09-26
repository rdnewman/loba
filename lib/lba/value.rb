module Lba
  # rubocop:disable Metrics/ParameterLists -- matches Internal::Value's public kwarg surface

  # Records a value, with the class, method, file, and line it was called from,
  # as one JSON line in this run's sink.
  #
  # Does nothing inside a Rails production environment; there is no override.
  #
  # @param argument [Symbol, Object] (required) a +Symbol+ names a local variable,
  #   instance variable, method, or expression in the caller, which is evaluated
  #   there; anything else is recorded as given. A +Symbol+ is evaluated as code, so
  #   it must be one you wrote, never one built from untrusted input.
  # @param label [String, Symbol] explicit label for the record; default is to infer
  #   one from a +Symbol+ argument (a non-+Symbol+ argument gets no label)
  # @param inspect [Boolean] +true+ to render a value that has no JSON form with
  #   +#inspect+; +false+ to use +#to_s+. Has no effect on JSON-native values.
  # @param log [Boolean] +true+ to also write the record to +Rails.logger+ (or
  #   +logger+, if given); +false+ to never log, even if +logger+ is given
  #   [default: +false+, unless +logger+ is given]
  # @param logger [Logger] a +Logger+ to also write the record to; implies
  #   +log: true+ unless +log: false+ is given
  # @param sink [IO, String] where to write instead of the default: an IO, or a
  #   file path (see the +LBA_SINK+ environment variable for a process-wide override)
  # @return [void]
  # @raise [ArgumentError] for an unknown keyword, such as loba's removed
  #   +production:+, +logdev:+, or +out:+
  # @raise [InvalidLoggerOptionError] if +logger+ is not a +Logger+
  #
  # @example Using a Symbol as the argument
  #   class HelloWorld
  #     def hello(name)
  #   Lba.val :name # putting Lba statements at the far left helps you remember to remove them
  #       "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> writes {"label":"name","value":"Charlie","class_name":"HelloWorld",
  #   #           "method_name":"hello","line":3,...}
  # @example Using a value directly, with a label
  #   Lba.val order.total, label: "Order total"
  # @example Also writing to Rails.logger
  #   Lba.val :name, log: true
  def self.val(argument, label: nil, inspect: true, log: nil, logger: nil, sink: nil)
    Internal::Value.record(argument, label:, inspect:, log:, logger:, sink:)
  end
  # rubocop:enable Metrics/ParameterLists
end
