require_relative "within_rails"

module Loba
  module Internal
    module Platform
      # Facts about the environment loba is running in, Rails or not.
      module Environment
        # The variables that name a non-Rails app's environment.
        ENVIRONMENT_VARIABLES = ["RACK_ENV", "APP_ENV", "RAILS_ENV"].freeze

        # Rails decides when it's loaded; otherwise any of RACK_ENV, APP_ENV,
        # or RAILS_ENV set to +production+ does.
        #
        # @return [Boolean] whether this is a production environment
        def self.production?
          if WithinRails.app?
            WithinRails.production?
          else
            production_by_variables?
          end
        end

        def self.production_by_variables?
          ENVIRONMENT_VARIABLES.any? do |name|
            ENV.fetch(name, nil) == "production"
          end
        end
        private_class_method :production_by_variables?
      end
    end
  end
end
