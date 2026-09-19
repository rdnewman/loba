module Lba
  module Internal
    module Platform
      module WithinRails
        def self.logger?
          return false unless defined?(::Rails)

          !!::Rails.logger
        end

        def self.production?
          return false unless defined?(::Rails)

          ::Rails.env.production?
        end
      end
    end
  end
end
