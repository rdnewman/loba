module Loba
  module Internal
    module Platform
      # Internal module for considering Rails
      module WithinRails
        # Determines if Rails has its logger defined (generally +true+)
        # @return [boolean] +true+ if +Rails.logger+ is defined
        def logger?
          Internal.boolean_cast(defined?(Rails)) && Internal.boolean_cast(Rails.logger)
        end
        module_function :logger?

        # Determines if Rails is running in a production environment
        # @return [boolean] +true+ if +Rails.env+ is +:production+
        def production?
          Internal.boolean_cast(defined?(Rails)) && Rails.env.production?
        end
        module_function :production?
      end
    end
  end
end
