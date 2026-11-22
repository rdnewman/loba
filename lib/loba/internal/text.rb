module Loba
  module Internal
    # Makes text from the traced program safe to join with other text and to
    # write. Such text can be in any encoding, or not be valid at all, and
    # joining two Strings in clashing encodings raises.
    module Text
      # Stands in for the message of an error whose +#message+ raises.
      UNREADABLE_MESSAGE = "(unreadable message)".freeze

      class << self
        # Converts the text to UTF-8, and never raises. A binary String's bytes
        # are read as UTF-8, so UTF-8 text that was only tagged binary stays
        # readable; so are those of an encoding Ruby can't convert from, such as
        # UTF-7.
        #
        # @param text [String] a String in any encoding
        # @return [String] valid UTF-8, with U+FFFD for bytes that couldn't be
        #   converted or read as UTF-8
        def make_utf8(text)
          if text.encoding == Encoding::BINARY
            read_as_utf8(text)
          else
            text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
          end
        rescue Encoding::ConverterNotFoundError
          read_as_utf8(text)
        end

        # An error as text, for a record or a warning.
        #
        # @param error [Exception] the error
        # @return [String] valid UTF-8, as +"Class: message"+
        def of_error(error)
          "#{make_utf8(error.class.to_s)}: #{message_of(error)}"
        end

      private

        def read_as_utf8(text)
          text.dup.force_encoding(Encoding::UTF_8).scrub
        end

        # An exception's +#message+ can be the traced program's own code, which
        # can raise while loba is already handling that exception.
        def message_of(error)
          make_utf8(error.message.to_s)
        rescue StandardError
          UNREADABLE_MESSAGE
        end
      end
    end
  end
end
