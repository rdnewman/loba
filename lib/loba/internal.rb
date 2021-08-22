require_relative 'internal/platform'
require_relative 'internal/time_keeper'
require_relative 'internal/value'

module Loba
  # @api private
  module Internal
    def strip_quotes(content)
      return content unless content.is_a?(String)
      return content unless content[0] == '"' && content[-1] == '"'

      if content.respond_to?(:delete_prefix)
        content.delete_prefix('"').delete_suffix('"')
      elsif content.respond_to?(:gsub)
        content.gsub(/\A"+|"+\z/, '')
      else
        content
      end
    end
    module_function :strip_quotes
  end
end
