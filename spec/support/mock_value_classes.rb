module LobaSpecSupport
  module MockValueClasses
    # Supports testing with random integers, strings [A-Za-z0-9], or trivial objects for
    # variable content and random strings for supplied labels.
    # Not intended for use outside of MockValuationClasses module.
    module Randomable
      def content
        @content ||= [
          rand(-1000..1000), # random number between -1000 and +1000
          rand(36**rand(10)).to_s(36), # random string, usually 10 chars long (may be shorter)
          trivial_class.new # trivial object
        ].sample.freeze
      end

      def label
        # random string, usually 10 chars long (may be shorter)
        @label ||= rand(36**rand(10)).to_s(36).freeze
      end

      def trivial_class
        Class.new do
          attr_accessor :somevar

          def initialize
            @somevar = rand(-1000..1000)
          end

          def somemethod
            5
          end
        end
      end
    end

    # For direct use in RSpec for cases testing use of local variables in calls to Valuation
    class LocalVariable
      extend Randomable

      def symbol_without_label
        _v = self.class.content
        Loba::Internal::Value.phrases(argument: :_v)
      end

      def symbol_with_label
        _v = self.class.content
        Loba::Internal::Value.phrases(argument: :_v, label: self.class.label)
      end

      def direct_without_label
        v = self.class.content
        Loba::Internal::Value.phrases(argument: v)
      end

      def direct_with_label
        v = self.class.content
        Loba::Internal::Value.phrases(argument: v, label: self.class.label)
      end
    end

    # For direct use in RSpec for cases testing use of instance variables in calls to Valuation
    class InstanceVariable
      extend Randomable

      def initialize
        @v = self.class.content
      end

      def symbol_without_label
        Loba::Internal::Value.phrases(argument: :@v)
      end

      def symbol_with_label
        Loba::Internal::Value.phrases(argument: :@v, label: self.class.label)
      end

      def direct_without_label
        Loba::Internal::Value.phrases(argument: @v)
      end

      def direct_with_label
        Loba::Internal::Value.phrases(argument: @v, label: self.class.label)
      end
    end

    # For direct use in RSpec for cases testing use of local variables in calls to Valuation
    class LocalVariableWithoutInspect
      extend Randomable

      def symbol_without_label
        _v = self.class.content
        Loba::Internal::Value.phrases(argument: :_v, inspect: false)
      end

      def symbol_with_label
        _v = self.class.content
        Loba::Internal::Value.phrases(argument: :_v, label: self.class.label, inspect: false)
      end

      def direct_without_label
        v = self.class.content
        Loba::Internal::Value.phrases(argument: v, inspect: false)
      end

      def direct_with_label
        v = self.class.content
        Loba::Internal::Value.phrases(argument: v, label: self.class.label, inspect: false)
      end
    end

    # For direct use in RSpec for cases testing use of instance variables in calls to Valuation
    class InstanceVariableWithoutInspect
      extend Randomable

      def initialize
        @v = self.class.content
      end

      def symbol_without_label
        Loba::Internal::Value.phrases(argument: :@v, inspect: false)
      end

      def symbol_with_label
        Loba::Internal::Value.phrases(argument: :@v, label: self.class.label, inspect: false)
      end

      def direct_without_label
        Loba::Internal::Value.phrases(argument: @v, inspect: false)
      end

      def direct_with_label
        Loba::Internal::Value.phrases(argument: @v, label: self.class.label, inspect: false)
      end
    end
  end
end
