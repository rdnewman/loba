require 'loba/version'

require 'singleton'
require 'binding_of_caller'
require 'colorize'

# Loba module for quick tracing of Ruby and Rails.
# If a Rails application, will use Rails.logger.debug.
# If not a Rails application, will use STDOUT.
module Loba

  # Outputs a timestamped notice, useful for quick traces to see the code path.
  # Also does a simple elapsed time check since the previous timestamp notice to help with quick, minimalist profiling.
  # @param options [Hash] options for use
  # @option options [Boolean] :production (false) true if this timestamp notice is enabled when running in :production environment
  # @return [NilClass] nil
  # @example Basic use
  #   def hello
  #     Loba.ts
  #   end
  #   #=> [TIMESTAMP] #=0001, diff=0.000463, at=1451615389.505411, in=/path/to/file.rb:2:in 'hello'
  def ts(options = {})

    # evaluate options
    filtered_options = Internal.filter_options(options, [:production])
    production_is_ok = filtered_options[:production]

    # log if possible
    if Internal::Platform.logging_ok?(production_is_ok)
      @loba_logger ||= Internal::Platform.logger
      @loba_timer ||= Internal::TimeKeeper.instance

      begin
        @loba_timer.timenum += 1
        timenow    = Time.now()
        stamptag   = '%04d'%(@loba_timer.timenum)
        timemark   = '%.6f'%(timenow.round(6).to_f)
        timechg    = '%.6f'%(timenow - @loba_timer.timewas)
        @loba_logger.call "[TIMESTAMP]".black.on_light_black +
                          " #=".yellow +
                          "#{stamptag}" +
                          ", diff=".yellow +
                          "#{timechg}" +
                          ", at=".yellow +
                          "#{timemark}" +
                          "    \t(in=#{caller[0]})".light_black
        @loba_timer.timewas = timenow
      rescue StandardError => e
        @loba_logger.call "[TIMESTAMP] #=FAIL, in=#{caller[0]}, err=#{e}".colorize(:red)
      end
    end
    nil
  end
  module_function :ts

  # Outputs a value notice showing value of provided argument including method and class identification
  # @param argument [various] the value to be evaluated and shown; if given as a Symbol, a label based on the argument will proceed the value the argument refers to
  # @param label [String] an optional, explicit label to be used instead of attempting to infer from the argument
  # @param options [Hash] options for use
  # @option options [Boolean] :inspect (true) true if this value notice is to use #inspect against the content being evaluated
  # @option options [Boolean] :production (false) true if this value notice is enabled when running in :production environment
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
  def val(argument = :nil, label = nil, options = {inspect: true})

    # evaluate options
    filtered_options = Internal.filter_options(options, [:production, :inspect])
    production_is_ok = filtered_options[:production]
    will_inspect = filtered_options[:inspect]

    # log if possible
    if Internal::Platform.logging_ok?(production_is_ok)
      depth = 0
      @loba_logger ||= Internal::Platform.logger

      tag = Internal.calling_tag(depth+1)
      name = argument.is_a?(Symbol) ? "#{argument}:" : nil

      text = if label.nil?
               name
             else
               label.strip!
               label += ':' unless label[-1] == ':'
             end

      result = if argument.is_a?(Symbol)
                 if will_inspect
                   binding.of_caller(depth+1).eval(argument.to_s).inspect
                 else
                   binding.of_caller(depth+1).eval(argument.to_s)
                 end
               else
                 if will_inspect
                   argument.inspect
                 else
                   argument
                 end
               end

      source_line = Internal.calling_source_line(depth+1)

      @loba_logger.call "#{tag} ".green +
                        "#{text.nil? ? '' : "#{text}"} ".light_green +
                        "#{result.nil? ? '-nil-' : result}" +
                        "    \t(in #{source_line})".light_black
    end
    nil
  end
  module_function :val


  module Internal

    class << self

      # Prepare display of class name from where Loba was invoked
      def calling_class_name(depth = 0)
        m = binding.of_caller(depth+1).eval('self.class.name')
        if m.nil? || m.empty?
          '<anonymous class>'
        elsif m == 'Class'
          binding.of_caller(depth+1).eval('self.name')
        else
          m
        end
      end

      # Prepare display of method name from where Loba was invoked
      def calling_method_name(depth = 0)
        m = binding.of_caller(depth+1).eval('self.send(:__method__)')
        (m.nil? || m.empty?) ? '<anonymous method>' : m
      end

      # Prepare display of whether the method from where Loba was invoked is for a class or an instance
      def calling_method_type(depth = 0)
        if binding.of_caller(depth+1).eval('self.class.name') == 'Class'
          :class
        else
          :instance
        end
      end

      # Prepare display of line number from where Loba was invoked [UNUSED]
      def calling_line_number(depth = 0)
        binding.of_caller(depth+1).eval('__LINE__')
      end

      # Assemble display that shows the method invoking Loba
      def calling_tag(depth = 0)
        delim = {class: '.', instance: '#'}
        "[#{calling_class_name(depth+1)}#{delim[calling_method_type(depth+1)]}#{calling_method_name(depth+1)}]"
      end

      # Identify source code line from where Loba was invoked
      def calling_source_line(depth = 0)
        caller[depth]
      end

      # Filters options argument for deprecated or unexpected use
      def filter_options(options, allowed_keys = [])
        result = {}
        allowed_keys.each { |key| result[key] = false }

        case options
        when Hash
          allowed_keys.each do |key|
            result[key] = !!options[key] unless options[key].nil?
          end
        when TrueClass
          if allowed_keys.include? :production
            Internal::Deprecated._0_3_0(true)
            result[:production] = true
          end
        when FalseClass
          Internal::Deprecated._0_3_0(false)
        else   # to be safe, treat as false
          Internal::Deprecated._0_3_0(false)
        end

        result
      end

    end

    # Internal class for deprecation warnings.
    class Deprecated
      class << self
        # Deprecations as of version 0.3.0
        # @param value [boolean] deprecated value supplied in original call to use in deprecation message
        def _0_3_0(value)
          bool = value ? "true" : "false"
          verb = value ? "enabled" : "disabled"
          warn "DEPRECATION WARNING: use {:production => #{bool}} instead to indicate notice is #{verb} in production"
        end
      end
    end

    # Internal class for tracking time stamps; should not be used directly
    # @!attribute [rw] timewas
    #   Previous timestamped Time value
    # @!attribute [rw] timenum
    #   Count of timestamping occurances so far
    class TimeKeeper
      include Singleton
      attr_accessor :timewas, :timenum
      def initialize
        @timewas, @timenum = Time.now, 0
      end
    end

    # Internal class for managing logging across Rails and non-Rails applications
    class Platform
      class << self
        # Returns true if Rails appears to be available
        def rails?
          defined?(Rails)
        end

        # Returns true if logging is to be allowed
        def logging_ok?(force_true = false)
          return true if force_true
          return true unless rails?
          begin
            !Rails.env.production?
          rescue
            true   # not Rails production if Rails isn't recognized
          end
        end

        # Returns a logging mechanism appropriate for the application
        def logger
          if (rails? && Rails.logger.present?)
            ->(arg){Rails.logger.debug arg}
          else
            ->(arg){puts arg}
          end
        end
      end
    end

  end   # module Internal

end   # module Loba
