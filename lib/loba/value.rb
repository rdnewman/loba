module Loba # rubocop:disable Style/Documentation
  # Outputs a value notice showing value of provided argument including method and
  # class identification.
  # @param argument [various] (required) the value to be evaluated and shown; if given as
  #   a +Symbol+, a label based on the argument will proceed the value the argument refers to
  # @param label [String] explicit label to be used instead of attempting
  #   to infer from the argument; default is to attempt to infer a label from the argument
  # @param inspect [boolean] +true+ if this value notice is to use +#inspect+ against the
  #   content being evaluated; otherwise, +false+
  # @param production [boolean]
  #   set to +true+ if the value notice is to be recorded
  #   when running in a Rails production environment
  # @param log [boolean]
  #   set to +false+ if no logging is ever wanted
  #   (default when not in Rails and +logger+ is nil);
  #   set to +true+ if logging is always wanted (default when in Rails or
  #   when +logger+ is set or +out+ is false);
  # @param logger [Logger] override logging with specified Ruby Logger
  # @param logdev [nil, String, IO, File::NULL]
  #   custom log device to use (when not in Rails); ignored if +logger+ is set;
  #   must be filename or IO object
  # @param out [boolean]
  #   set to +false+ if console output is to be suppressed
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
  # @note To avoid doubled output, if a non-Rails logger is to be logged to and +logdev+ is
  #   set to +$stdout+, then output will be suppressed (i.e., +settings.out+ is +false+).
  #   Doubled output can still occur; in that case, explicitly use +out: false+.
  def value( # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/ParameterLists
    argument,
    label: nil,
    inspect: true,
    production: false,
    log: false,
    logger: nil,
    logdev: nil,
    out: true
  )
    settings = Internal::Settings.new(
      log: log, logger: logger, logdev: logdev, out: out, production: production
    )

    return unless settings.enabled?

    text = Internal::Value.phrases(
      argument: (argument.nil? ? :nil : argument),
      label: label,
      inspect: inspect,
      depth_offset: 1
    )

    Internal::Platform.writer(settings: settings).call(
      # NOTE: while tempting, memoizing Internal::Platform.logger can lead to surprises
      #   if Rails presence isn't constant
      #
      # warning: nested interpolation below (slight help to performance)
      # 60: light_black
      # 62: light_green
      "#{Rainbow("#{text[:tag]} ").green.bg(:default)}" \
      "#{Rainbow("#{text[:label]} ").color(62)}" \
      "#{text[:value]}" \
      "#{Rainbow("    \t(in #{text[:line]})").color(60)}"
    )

    nil
  end
  module_function :value

  # Shorthand alias for Loba.value.
  # @!method val(argument, label: nil, inspect: true, production: false, log: false, logger: nil, logdev:nil, out: true)
  alias val value
  module_function :val
end
