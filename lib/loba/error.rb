module Loba
  # Errors raised by Loba are subclasses of +Loba::Error+.
  # Rescue this class to rescue any Loba-specific errors.
  # @api private
  class Error < StandardError; end

  # Error raised with an invalid logdev is specified
  # @api private
  class InvalidLogdevOptionError < Error; end

  # Error raised with an invalid logger is specified
  # @api private
  class InvalidLoggerOptionError < Error; end

  # Error raised with an invalid target for #puts is specified
  # @api private
  class InvalidOutOptionError < Error; end
end
