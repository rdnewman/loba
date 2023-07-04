require_relative 'internal/platform'
require_relative 'internal/time_keeper'
require_relative 'internal/value'

module Loba
  # Internal functionality support
  # @api private
  module Internal
    # Remove wrapping quotes on a string (produced by .inspect)
    #
    # @param content [String] the string (assumed to be produced from calling .inspect)
    #   to remove quotes (") that wrap a string
    #
    # @return [String, Object]
    #   * If not a string, the original argument will be returned without modification
    #   * If string does not have quotes as first and last character, the original
    #     argument will be returned without modification
    #   * If string does have quotes as first and last character, the original content
    #     will be returned with the original first and last character removed
    def unquote(content)
      return content unless content.is_a?(String)
      return content unless content[0] == '"' && content[-1] == '"'

      content[1...-1]
    end
    module_function :unquote
  end
end
