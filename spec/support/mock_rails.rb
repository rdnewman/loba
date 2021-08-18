require 'logger'

module LobaSpecSupport
  module MockRails
    class Base
      class << self
        def env
          nil
        end

        def logger
          nil
        end

        def mocked_output
          @mocked_output ||= StringIO.new
        end
      end
    end

    class LoggingUndefined < Base
      def self.logger
        @logger ||= MockAbsentLogger.new(mocked_output)
      end
    end

    class LoggingDefined < Base
      def self.logger
        @logger ||= MockPresentLogger.new(mocked_output)
      end
    end

    class MockPresentLogger < Logger
      def present?
        true
      end
    end

    class MockAbsentLogger < Logger
      def present?
        false
      end
    end

    class MockEnvProduction
      def production?
        true
      end
    end

    class MockEnvNonproduction
      def production?
        false
      end
    end
  end
end
