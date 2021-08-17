require 'binding_of_caller'
# require_relative 'internal/call_location'
require_relative 'internal/platform'
require_relative 'internal/time_keeper'
# require_relative 'internal/valuation'
require_relative 'internal/value'

module Loba
  module Internal

    # Filters options argument for supported values
    # @param options [various] options argument to filter
    # @param allowed_keys [array] array of expected keys in options
    def self.filter_options(options, allowed_keys = [])
      # allowed keys are always there and default to false
      default = allowed_keys.each_with_object({}) { |key, hash| hash[key] = false }

      # abort with that default result if given options aren't usuable
      return default unless options.is_a?(Hash)

      # ensure given options have boolean values and return the result
      allowed_keys.each_with_object(default) do |key, result|
        next if options[key].nil?

        result[key] = options[key] ? true : false
      end
    end

    # # Retrieve a value used in code.
    # #
    # # @param argument [Symbol, Object] the value or variable for which information is
    # #   to be retrieved
    # #   * If a symbol, it is assumed to be a reference to a variable
    # #     and a label can be inferred.
    # #   * If any other type, it is assumed to be a literal value to
    # #     and a label should be supplied when instantiated.
    # # @param label [String] an explicit label to use; will override any possible inferred label
    # # @param inspection [Boolean] force #inspect to be called against `argument` when evaluating
    # #
    # # @return [Hash] various detail about the value being analyzed
    # #   * :tag => [String] method name (wrapped in square brackets)
    # #   * :line => [String] code line reference
    # #   * :value => [String] value of argument (if nil, '-nil-' is returned)
    # #   * :label => [String] label, ending with ":"
    # #     (if not possible to infer, '[unknown value]' is returned)
    # def self.phrases(argument, label = nil, inspection = true, depth_offset = 0)
    #   depth = depth_offset&.to_i || 0
    #   {
    #     tag: Value.tag(depth + 1),
    #     line: Value.source_line(depth + 1),
    #     value: Value.value(argument, inspection, depth + 1),
    #     label: Value.label(argument, label)
    #   }
    # end


    # def self.phrases(argument, label = nil, inspection = true)
    #   {
    #     tag: CallLocation.tag(depth + 1),
    #     line: CallLocation.source_line(depth + 1),
    #     value: value(argument, inspection, 1),
    #     label: label(argument, label)
    #   }
    # end

#     # Builds a label for display based on the argument when instantiated.
#     # If the argument (when instantiated) is not a symbol, it may not be possible
#     # to infer a label; in that case, '[unknown value]' is returned.
#     #
#     # @return [String] label
#     def label(argument, supplied_label)
#       text = if supplied_label.nil?
#                argument.is_a?(Symbol) ? "#{argument}:" : nil
#              else
#                s = supplied_label.strip
#                s += ':' unless s[-1] == ':'
#                s
#              end

#       text.nil? ? '[unknown value]:' : text.to_s
#     end

#     def value(argument, want_inspection, depth_offset = 0)
#       return want_inspection ? argument.inspect : argument unless argument.is_a?(Symbol)

#       depth = 1 + (depth_offset || 0)

# # # return nil
# # # p "depth     = #{depth}"
# # # p "depth + 1 = #{depth+1}"
# # begin
# #   LobaSpecSupport::OutputControl.redirect!('./loba_val_spec.txt')
# #   p "depth     = #{depth}"
# #   p "depth + 1 = #{depth+1}"

# #   xs = []
# #   n = 0; xs << [n, binding.of_caller(n)]
# #   n = 1; xs << [n, binding.of_caller(n)]
# #   n = 2; xs << [n, binding.of_caller(n)]
# #   n = 3; xs << [n, binding.of_caller(n)]
# #   n = 4; xs << [n, binding.of_caller(n)]
# #   n = 5; xs << [n, binding.of_caller(n)]
# #   n = 6; xs << [n, binding.of_caller(n)]

# #   # x = binding.of_caller(depth + 1)
# #   p argument
# #   p argument.to_s
# #   xs.each do |x|
# #   puts "======="
# #   n = x[0]
# #   b = x[1]
# #   puts "n = #{n}"
# #   pp b.__send__(:caller_locations)
# #   y = b.eval(argument.to_s) rescue 'failed'
# #   p "result = #{y}"
# #   end
# #   # will_inspect = filtered_options[:inspect]
# #   # value = if argument.is_a?(Symbol)
# #   #   if will_inspect
# #   #     binding.of_caller(1).eval(argument.to_s).inspect
# #   #   else
# #   #     binding.of_caller(1).eval(argument.to_s)
# #   #   end
# #   # else
# #   #   will_inspect ? argument.inspect : argument
# #   # end
# #   puts "======="
# #   puts "BEFORE eval..."
# #   n = 5
# #   puts "target depth = #{n}"
# #   b = binding.of_caller(n)
# #   pp b.__send__(:caller_locations)
# #   y = b.eval(argument.to_s) rescue 'failed'
# #   p "result = #{y}"
# #   puts "======="
# #   puts "depth              = #{depth}"
# #   puts "want_inspection    = #{want_inspection}"
# #   puts "----"
# #   puts "about to eval..."

# #   evaluation = binding.of_caller(depth + 1).eval(argument.to_s)


# #   puts "====="
# #   puts "evaluation         = #{evaluation}"
# #   puts "evaluation.inspect = #{evaluation.inspect}"
# #   puts "############"

# # ensure
# #   LobaSpecSupport::OutputControl.suppress! # or restore!
# # end

# # return nil

#       evaluation = binding.of_caller(depth + 1).eval(argument.to_s)
#       want_inspection ? evaluation.inspect : evaluation
#     end
  end
end
