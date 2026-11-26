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
          "#{make_utf8(class_text(error.class))}: #{message_of(error)}"
        end

        # A module's name. Its own +name+ method comes first, since it can name
        # an anonymous class (as specs often do); it runs the traced program's
        # code, so if it raises or returns something other than a String, the
        # constant's name is used.
        #
        # @param mod [Module] a module or class
        # @return [String, nil] the name; +nil+ for an anonymous module that
        #   doesn't name itself
        def name_of(mod)
          given = mod.name

          if string?(given)
            given
          else
            constant_name_of(mod)
          end
        rescue StandardError
          constant_name_of(mod)
        end

      private

        def constant_name_of(mod) = ::Module.instance_method(:name).bind_call(mod)

        def module_text_of(mod) = ::Module.instance_method(:to_s).bind_call(mod)

        # Module#=== also works on a BasicObject, which has no #is_a?.
        def string?(text)
          ::String === text # rubocop:disable Style/CaseEquality -- see above
        end

        # An error class's own +to_s+ is the traced program's code, which can
        # raise while loba is already handling the error.
        def class_text(error_class)
          given = error_class.to_s

          if string?(given)
            given
          else
            module_text_of(error_class)
          end
        rescue StandardError
          module_text_of(error_class)
        end

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
