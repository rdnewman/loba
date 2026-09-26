module Lba
  # Base class for errors lba raises; rescue it to rescue any of them.
  class Error < StandardError; end

  # Raised when the +logger:+ option is given something other than a +Logger+.
  class InvalidLoggerOptionError < Error; end
end
