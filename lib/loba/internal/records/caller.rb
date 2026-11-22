require_relative "../text"

module Loba
  module Internal
    module Records
      # The fields that describe the calling frame, shared by value and
      # timestamp records.
      module Caller
        class << self
          # @param caller_binding [CallerBinding] the calling frame
          # @return [Hash{Symbol => Object}] +:file+, +:line+, +:class_name+,
          #   +:method_name+, and +:method_type+, in that order
          def fields(caller_binding)
            {
              file: utf8(caller_binding.file),
              line: caller_binding.line,
              class_name: utf8(caller_binding.class_name),
              method_name: utf8(caller_binding.method_name),
              method_type: caller_binding.method_type
            }
          end

        private

          # A method defined from binary text has a name tagged binary, and json
          # writes such text with a deprecation warning on the traced program's
          # $stderr. Other text passes through; Records::Json makes it valid.
          def utf8(text)
            if text.encoding == Encoding::BINARY
              Text.make_utf8(text.to_s)
            else
              text
            end
          end
        end
      end
    end
  end
end
