module Lba
  module Internal
    # Facts about the environment lba is running in.
    module Platform
      # Facts about the Rails app lba is running in, if any.
      module WithinRails
        # @return [Boolean] whether Rails is loaded and has a logger
        def self.logger?
          return false unless rails_responds_to?(:logger)

          !!::Rails.logger
        end

        # @return [Boolean] whether Rails is loaded and running in production
        def self.production?
          return false unless rails_responds_to?(:env)

          ::Rails.env.production?
        end

        # Gems such as rails-html-sanitizer define a Rails namespace without
        # Rails itself, so a defined Rails constant isn't enough.
        def self.rails_responds_to?(name)
          defined?(::Rails) && ::Rails.respond_to?(name)
        end
        private_class_method :rails_responds_to?
      end
    end
  end
end
