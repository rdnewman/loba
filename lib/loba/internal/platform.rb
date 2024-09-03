require_relative 'platform/formatter'
require_relative 'platform/within_rails'

module Loba
  module Internal
    # Internal module for managing output and logging across Rails and non-Rails applications
    module Platform
      class << self
        # Provides mechanism for appropriate console output and logging.
        #
        # @note To avoid doubled output, if a non-Rails logger is to be logged to and +logdev+ is
        #   set to +$stdout+, then output will be suppressed (i.e., +settings.out+ is +false+).
        #   Doubled output can still occur; in that case, explicitly use +out: false+.
        #
        # @param settings [::Loba::Internal::Settings] settings for output control
        # @return [lambda {|message| ...}] procedure for presenting output. Takes one argument,
        #   +message+ (String), for the output to be written
        def writer(settings:)
          lambda do |message|
            puts(message) if settings.out?

            settings.logger.debug { message } if settings.log?
          end
        end
      end
    end
  end
end
