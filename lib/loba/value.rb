module Loba
  # Outputs a value notice showing value of provided argument including method and
  # class identification.
  # @param argument [various] (required) the value to be evaluated and shown; if given as
  #   a Symbol, a label based on the argument will proceed the value the argument refers to
  # @param label [String] explicit label to be used instead of attempting
  #   to infer from the argument; default is to attempt to infer a label from the argument
  # @param inspect [Boolean] true if this value notice is to use #inspect against the
  #   content being evaluated; otherwise, false
  # @param production [Boolean] set to true if this timestamp notice is
  #   to be recorded when running in :production environment
  # @param log [Boolean] when false, will not write to any logger; when true, will write to a log
  # @return [NilClass] nil
  # @example Using Symbol as argument
  #   class HelloWorld
  #     def hello(name)
  #   Loba.value :name # putting Loba statement to far left helps remember to remove later
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] name: Charlie        (at /path/to/file/hello_world.rb:3:in 'hello')
  #   #=> Hello, Charlie!
  # @example Using non-Symbol as argument
  #   class HelloWorld
  #     def hello(name)
  #   Loba.val name # Loba.val is a shorthand alias for Loba.value
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] Charlie        (at /path/to/file/hello_world.rb:3:in 'hello')
  #   #=> Hello, Charlie!
  # @example Using non-Symbol as argument with a label
  #   class HelloWorld
  #     def hello(name)
  #   Loba.value name, "Name:"
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] Name: Charlie        (at /path/to/file/hello_world.rb:3:in 'hello')
  #   #=> Hello, Charlie!
  def value(argument, label: nil, inspect: true, production: false, log: false) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return nil unless Internal::Platform.logging_allowed?(production)

    text = Internal::Value.phrases(
      argument: (argument.nil? ? :nil : argument),
      label: label,
      inspect: inspect,
      depth_offset: 1
    )

    Internal::Platform.logger.call(
      # NOTE: while tempting, memoizing Internal::Platform.logger can lead to surprises
      #   if Rails presence isn't constant
      #
      # warning: nested interpolation below (slight help to performance)
      # 60: light_black
      # 62: light_green
      "#{Rainbow("#{text[:tag]} ").green.bg(:default)}" \
      "#{Rainbow("#{text[:label]} ").color(62)}" \
      "#{text[:value]}" \
      "#{Rainbow("    \t(in #{text[:line]})").color(60)}",
      !!log
    )

    nil
  end
  module_function :value

  # Shorthand alias for Loba.value.
  # @!method val(argument, label: nil, inspect: true, production: false, log: false)
  alias val value
  module_function :val
end
