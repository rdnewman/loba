module Lba
  module Internal
    # Facts about the environment lba is running in.
    module Platform
      # Facts about the Rails app lba is running in, if any.
      module WithinRails
        # @return [Boolean] whether Rails is loaded and has a logger
        def self.logger?
          return false unless defined?(::Rails)

          !!::Rails.logger
        end

        # @return [Boolean] whether Rails is loaded and running in production
        def self.production?
          return false unless defined?(::Rails)

          ::Rails.env.production?
        end
      end
    end
  end
end
