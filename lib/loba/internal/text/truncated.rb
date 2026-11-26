module Loba
  module Internal
    module Text
      # Text kept within a length limit: the start of the text, with anything
      # past the limit cut off and counted in a marker.
      class Truncated
        # Longest text kept, in characters. The marker doesn't count toward
        # it. 500 is a guess.
        MAX_LENGTH = 500

        # @return [Integer] characters cut off; +0+ if none were
        attr_reader :chars_cut

        # @param text [String] the text
        def initialize(text)
          @text = text
          @chars_cut = [text.length - MAX_LENGTH, 0].max
        end

        # @return [Boolean] +true+ if any characters were cut off
        def cut?
          chars_cut.positive?
        end

        # @return [String] the text, or if it's longer than MAX_LENGTH, its
        #   first MAX_LENGTH characters followed by +" [+N chars]"+
        def to_s
          if cut?
            "#{text[0...MAX_LENGTH]} [+#{chars_cut} chars]"
          else
            text
          end
        end

      private

        attr_reader :text
      end
    end
  end
end
