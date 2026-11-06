require "json"

module Loba
  module Internal
    module Records
      # Writes records as JSON text, which is UTF-8. Text in a record comes from
      # the traced program (error messages, class and method names, file paths),
      # and text that isn't UTF-8 must not break the traced code.
      module Json
        class << self
          # Writes the record as JSON. If its text can't be written, bytes that
          # aren't valid UTF-8 become U+FFFD. Anything else JSON refuses is
          # loba's own bug, and raises.
          #
          # @param fields [Hash] the record
          # @return [String] the JSON text
          # @raise [JSON::GeneratorError] if the record can't be written even
          #   with its text made valid
          def generate(fields)
            ::JSON.generate(fields)
          rescue ::JSON::GeneratorError
            ::JSON.generate(with_valid_text(fields))
          end

          # A binary String's bytes are read as UTF-8, so UTF-8 text that was
          # only tagged binary stays readable.
          #
          # @param text [String] any String
          # @return [String] valid UTF-8, with U+FFFD for bytes that couldn't be
          #   read as UTF-8
          def utf8(text)
            if text.encoding == Encoding::BINARY
              text.dup.force_encoding(Encoding::UTF_8).scrub
            else
              text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
            end
          end

        private

          def with_valid_text(item)
            case item
            when String
              utf8(item)
            when Symbol
              utf8(item.name)
            when Array
              item.map { with_valid_text(_1) }
            when Hash
              item.to_h { |key, entry| [with_valid_text(key), with_valid_text(entry)] }
            else
              item
            end
          end
        end
      end
    end
  end
end
