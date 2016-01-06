require 'loba/version'
require 'singleton'
require 'rails'
require 'binding_of_caller'
require 'colorize'

# Loba module for quick tracing of Ruby and Rails.
# If a Rails application, will use Rails.logger.debug.
# If not a Rails application, will use STDOUT.
module Loba

  # Outputs a timestamped notice, useful for quick traces to see the code path.
  # Also does a simple elapsed time check since the previous timestamp notice to help with quick, minimalist profiling.
  # @param production_is_ok [Boolean] true if this timestamp notice is enabled when running in :production environment
  # @return [NilClass] nil
  # @example Basic use
  #   def hello
  #     Loba::ts
  #   end
  #   #=> [TIMESTAMP] #=0001, diff=0.000463, at=1451615389.505411, in=/path/to/file.rb:2:in 'hello'
  def Loba::ts(production_is_ok = false)
    if Platform.logging_ok?(production_is_ok)  # don't waste calculation in production since logging messages won't show up anyway
      @loba_logger ||= Platform.logger
      @loba_timer ||= Loba::TimeKeeper.instance

      begin
        @loba_timer.timenum += 1
        timenow    = Time.now()
        stamptag   = '%04d'%@loba_timer.timenum
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

  # Outputs a value notice showing value of provided argument including method and class identification
  # @param argument [various] the value to be evaluated and shown; if given as a Symbol, a label based on the argument will proceed the value the argument refers to
  # @param label [String] an optional, explicit label to be used instead of attempting to infer from the argument
  # @return [NilClass] nil
  # @example Using Symbol as argument
  #   class HelloWorld
  #     def hello(name)
  #   Loba::val :name       # best to put Loba statement to far left for easy removal when done
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] name: Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
  #   #=> Hello, Charlie!
  # @example Using non-Symbol as argument
  #   class HelloWorld
  #     def hello(name)
  #   Loba::val name
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
  #   #=> Hello, Charlie!
  # @example Using non-Symbol as argument with a label
  #   class HelloWorld
  #     def hello(name)
  #   Loba::val name, "Name:"
  #       puts "Hello, #{name}!"
  #     end
  #   end
  #   HelloWorld.new.hello("Charlie")
  #   #=> [HelloWorld#hello] Name: Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
  #   #=> Hello, Charlie!
  def Loba::val(argument = :nil, label = nil)
    depth = 0
    @loba_logger ||= Loba::Platform.logger
    tag = Loba::calling_tag(depth+1)
    name = argument.is_a?(Symbol) ? "#{argument.to_s}:" : nil
    text = if label.nil?
             name
           else
             label.strip!
             label += ':' unless label[-1] == ':'
           end
    result = argument.is_a?(Symbol) ? binding.of_caller(depth+1).eval(argument.to_s) : argument # eval(argument).inspect


    @loba_logger.call "#{tag} ".green +
                      "#{text.nil? ? '' : "#{text}"} ".light_green +
                      "#{result.nil? ? '[nil]' : result}" +
                      "    \t(in #{Loba::calling_source_line(depth+1)})".light_black
    nil
  end

private
  Loba::LOBA_CLASS_NAME = 'self.class.name'
  def Loba::calling_class_name(depth = 0)
    m = binding.of_caller(depth+1).eval(Loba::LOBA_CLASS_NAME)
    if m.blank?
      '<anonymous class>'
    elsif m == 'Class'
      binding.of_caller(depth+1).eval('self.name')
    else
      m
    end
  end

  def Loba::calling_class_anonymous?(depth = 0)
    binding.of_caller(depth+1).eval(Loba::LOBA_CLASS_NAME).blank?
  end

  Loba::LOBA_METHOD_NAME = 'self.send(:__method__)'
  def Loba::calling_method_name(depth = 0)
    m = binding.of_caller(depth+1).eval(Loba::LOBA_METHOD_NAME)
    m.blank? ? '<anonymous method>' : m
  end
  def Loba::calling_method_anonymous?(depth = 0)
     binding.of_caller(depth+1).eval(Loba::LOBA_METHOD_NAME).blank?
  end

  def Loba::calling_method_type(depth = 0)
    binding.of_caller(depth+1).eval('self.class.name') == 'Class' ? :class : :instance
  end

  def Loba::calling_line_number(depth = 0)
    binding.of_caller(depth+1).eval('__LINE__')
  end

  def Loba::calling_source_line(depth = 0)
    caller[depth]
  end

  def Loba::calling_tag(depth = 0)
    delim = {class: '.', instance: '#'}
    "[#{Loba::calling_class_name(depth+1)}#{delim[Loba::calling_method_type(depth+1)]}#{Loba::calling_method_name(depth+1)}]"
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
    # Returns true if Rails logging appears to be available
    def self.rails?
      !Rails.logger.nil?
    end

    # Returns true if logging is to be allowed
    def self.logging_ok?(force_true = false)
      return true if force_true
      return true unless Loba::Platform.rails?
      begin
        !Rails.env.production?
      rescue
        true   # not Rails production if Rails isn't recognized
      end
    end

    # Returns a logging mechanism appropriate for the application
    def self.logger
      Rails.logger.nil? ? ->(arg){puts arg} : ->(arg){Rails.logger.debug arg}
    end
  end

end
