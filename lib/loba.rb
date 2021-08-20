require 'loba/version'
require 'loba/internal'

require 'binding_of_caller'
require 'rainbow'

# Loba module for quick tracing of Ruby and Rails.
# If a Rails application, will use Rails.logger.debug.
# If not a Rails application, will use STDOUT.
module Loba
  # Outputs a timestamped notice, useful for quick traces to see the code path.
  # Also does a simple elapsed time check since the previous timestamp notice to
  # help with quick, minimalist profiling.
  # @param production [Boolean] set to true if this timestamp notice is
  #   to be recorded when running in :production environment
  # @return [NilClass] nil
  # @example Basic use
  #   def hello
  #     Loba.timestamp
  #   end
  #   #=> [TIMESTAMP] #=0001, diff=0.000463, at=1451615389.505411, in=/path/to/file.rb:2:in 'hello'
  # @example Forced to output when in production environment
  #   def hello
  #     Loba.ts production: true # Loba.ts is a shorthand alias for Loba.timestamp
  #   end
  #   #=> [TIMESTAMP] #=0001, diff=0.000463, at=1451615389.505411, in=/path/to/file.rb:2:in 'hello'
  def timestamp(production: false)
    return unless Internal::Platform.logging_ok?(production)

    # produce timestamp notice
    @loba_logger ||= Internal::Platform.logger

    begin
      stats = Internal::TimeKeeper.instance.ping
      @loba_logger.call(
        # 60: light_black / grey
        "#{Rainbow('[TIMESTAMP]').black.bg(60)}" \
        "#{Rainbow(' #=').yellow.bg(:default)}" \
        "#{format('%04d', stats[:number])}" \
        "#{Rainbow(', diff=').yellow}" \
        "#{format('%.6f', stats[:change])}" \
        "#{Rainbow(', at=').yellow}" \
        "#{format('%.6f', stats[:now].round(6).to_f)}" \
        "#{Rainbow("    \t(in #{caller(1..1).first})").color(60)}" # warning: nested interpolation
      )
    rescue StandardError => e
      @loba_logger.call Rainbow("[TIMESTAMP] #=FAIL, in=#{caller(1..1).first}, err=#{e}").red
    end

    nil
  end
  module_function :timestamp

  # Shorthand alias for Loba.timestamp.
  alias ts timestamp
  module_function :ts

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
  # @return [NilClass] nil
  # @example Using Symbol as argument
  #   class HelloWorld
  #     def hello(name)
  #   Loba.value :name # putting Loba statement to far left helps remember to remove later
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] name: Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
  #   #=> Hello, Charlie!
  # @example Using non-Symbol as argument
  #   class HelloWorld
  #     def hello(name)
  #   Loba.val name # Loba.val is a shorthand alias for Loba.value
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
  #   #=> Hello, Charlie!
  # @example Using non-Symbol as argument with a label
  #   class HelloWorld
  #     def hello(name)
  #   Loba.value name, "Name:"
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] Name: Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
  #   #=> Hello, Charlie!
  def value(argument, label: nil, inspect: true, production: false)
    return nil unless Internal::Platform.logging_ok?(production)

    @loba_logger ||= Internal::Platform.logger

    text = Internal::Value.phrases(
      argument: (argument.nil? ? :nil : argument),
      label: label,
      inspect: inspect,
      depth_offset: 1
    )
    @loba_logger.call(
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
  alias val value
  module_function :val
end
