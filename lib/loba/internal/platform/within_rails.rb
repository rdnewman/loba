module Loba
  module Internal
    module Platform
      # Internal module for considering Rails
      module WithinRails
        def logger?
          Internal.boolean_cast(defined?(Rails)) && Internal.boolean_cast(Rails.logger)
        end
        module_function :logger?

        def production?
          Internal.boolean_cast(defined?(Rails)) && Rails.env.production?
        end
        module_function :production?
      end
    end
  end
end
