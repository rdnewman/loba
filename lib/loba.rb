require 'loba/version'
require 'loba/internal'

require 'binding_of_caller'
require 'colorize'

# Loba module for quick tracing of Ruby and Rails.
# If a Rails application, will use Rails.logger.debug.
# If not a Rails application, will use STDOUT.
module Loba
  # Outputs a timestamped notice, useful for quick traces to see the code path.
  # Also does a simple elapsed time check since the previous timestamp notice to
  # help with quick, minimalist profiling.
  # @param options [Hash] options for use
  # @option options [Boolean] :production (false) true if this timestamp notice is
  #   enabled when running in :production environment
  # @return [NilClass] nil
  # @example Basic use
  #   def hello
  #     Loba.ts
  #   end
  #   #=> [TIMESTAMP] #=0001, diff=0.000463, at=1451615389.505411, in=/path/to/file.rb:2:in 'hello'
  def ts(options = {})
    # evaluate options
    filtered_options = Internal.filter_options(options, [:production])
    return nil unless Internal::Platform.logging_ok?(filtered_options[:production])

    # produce timestamp notice
    @loba_logger ||= Internal::Platform.logger
    @loba_timer ||= Internal::TimeKeeper.instance

    begin
      stats = @loba_timer.ping
      @loba_logger.call '[TIMESTAMP]'.black.on_light_black +
                        ' #='.yellow +
                        format('%04d', stats[:number]).to_s +
                        ', diff='.yellow +
                        format('%.6f', stats[:change]).to_s +
                        ', at='.yellow +
                        format('%.6f', stats[:now].round(6).to_f).to_s +
                        "    \t(in=#{caller(1..1).first})".light_black
    rescue StandardError => e
      @loba_logger.call "[TIMESTAMP] #=FAIL, in=#{caller(1..1).first}, err=#{e}".colorize(:red)
    end

    nil
  end
  module_function :ts

  # Alias for Loba.ts
  alias_method :timestamp, :ts
  module_function :timestamp

  # Outputs a value notice showing value of provided argument
  # including method and class identification
  # @param argument [various] the value to be evaluated and shown; if given as a Symbol,
  #   a label based on the argument will proceed the value the argument refers to
  # @param label [String] an optional, explicit label to be used instead of attempting
  #   to infer from the argument
  # @param options [Hash] options for use
  # @option options [Boolean] :inspect (true) true if this value notice is to use
  #   #inspect against the content being evaluated
  # @option options [Boolean] :production (false) true if this value notice is enabled
  #   when running in :production environment
  # @return [NilClass] nil
  # @example Using Symbol as argument
  #   class HelloWorld
  #     def hello(name)
  #   Loba.val :name       # best to put Loba statement to far left for easy removal when done
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] name: Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
  #   #=> Hello, Charlie!
  # @example Using non-Symbol as argument
  #   class HelloWorld
  #     def hello(name)
  #   Loba.val name
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
  #   #=> Hello, Charlie!
  # @example Using non-Symbol as argument with a label
  #   class HelloWorld
  #     def hello(name)
  #   Loba.val name, "Name:"
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] Name: Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
  #   #=> Hello, Charlie!
  def val(argument = :nil, label = nil, options = { inspect: true })
    # evaluate options
    filtered_options = Internal.filter_options(options, [:production, :inspect])
    return nil unless Internal::Platform.logging_ok?(filtered_options[:production])

    # produce value notice
    @loba_logger ||= Internal::Platform.logger

    depth = 0
    tag = Internal.calling_tag(depth + 1)
    name = argument.is_a?(Symbol) ? "#{argument}:" : nil

    text = if label.nil?
             name
           else
             label.strip!
             label += ':' unless label[-1] == ':'
           end

    will_inspect = filtered_options[:inspect]
    result = if argument.is_a?(Symbol)
               if will_inspect
                 binding.of_caller(depth + 1).eval(argument.to_s).inspect
               else
                 binding.of_caller(depth + 1).eval(argument.to_s)
               end
             else
               will_inspect ? argument.inspect : argument
             end

    source_line = Internal.calling_source_line(depth + 1)

    @loba_logger.call "#{tag} ".green +
                      "#{text.nil? ? '' : text.to_s} ".light_green +
                      (result.nil? ? '-nil-' : result).to_s +
                      "    \t(in #{source_line})".light_black

    nil
  end
  module_function :val
end
