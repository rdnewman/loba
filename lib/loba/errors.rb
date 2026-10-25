module Loba
  # Base class for errors loba raises; rescue it to rescue any of them.
  class Error < StandardError; end

  # Raised when a call would log and its +logger:+ option is something other
  # than a +Logger+.
  class InvalidLoggerOptionError < Error; end
end
