require 'loba/version'
require 'singleton'
require 'rails'
require 'binding_of_caller'

module Loba

  def Loba::ts(production_is_ok = false)
    if Loba::Platform.logging_ok?(production_is_ok)  # don't waste calculation in production since logging messages won't show up anyway
      @loba_logger ||= Loba::Platform.logger
      @loba_timer ||= Loba::TimeKeeper.instance

      begin
        @loba_timer.timenum += 1
        timenow    = Time.now()
        stamptag   = '%04d'%@loba_timer.timenum
        timemark   = '%.6f'%(timenow.round(6).to_f)
        timechg    = '%.6f'%(timenow - @loba_timer.timewas)
        @loba_logger.call "[TIMESTAMP] #=#{stamptag}, diff=#{timechg}, at=#{timemark}, in=#{caller[0]}"
        @loba_timer.timewas = timenow
      rescue StandardError => e
        @loba_logger.call "[TIMESTAMP] #=FAIL, in=#{caller[0]}, err=#{e}"
      end
    end
    nil
  end

  def Loba::val(argument = :nil, depth = 0)
    @loba_logger ||= Loba::Platform.logger
    tag = Loba::calling_tag(depth+1)
    name = argument.is_a?(Symbol) ? argument.to_s : nil
    result = argument.is_a?(Symbol) ? binding.of_caller(depth+1).eval(argument.to_s) : argument.inspect
    @loba_logger.call "#{tag} #{name.nil? ? '' : "#{name}:"} #{result.nil? ? '[nil]' : result}    \t(at #{Loba::calling_source_line(depth+1)})"
  end

private
  LOBA_CLASS_NAME = 'self.class.name'
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

  LOBA_METHOD_NAME = 'self.send(:__method__)'
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

  class TimeKeeper
    include Singleton
    attr_accessor :timewas, :timenum
    def initialize
      @timewas, @timenum = Time.now, 0
    end
  end

  class Platform
    def self.rails?
      !Rails.logger.nil?
    end

    def self.logging_ok?(force_true = false)
      return true if force_true
      return true unless Loba::Platform.rails?
      begin
        !Rails.env.production?
      rescue
        true   # not Rails production if Rails isn't recognized
      end
    end

    def self.logger
      Rails.logger.nil? ? ->(arg){puts arg} : ->(arg){Rails.logger.debug arg}
    end
  end

end
