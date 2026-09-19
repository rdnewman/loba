module Lba
  module Internal
    class Settings
      def initialize(log: nil, logger: nil)
        return unless enabled?

        @log_mirror = LogMirror.for(log:, logger:)
      end

      def log? = !log_mirror.nil?

      def logger = log_mirror&.logger

      def enabled? = !Internal::Platform::WithinRails.production?

      def disabled? = !enabled?

    private

      attr_reader :log_mirror
    end
  end
end
