module Loba
  # Outputs a timestamped notice, useful for quick traces to see the code path.
  # Also does a simple elapsed time check since the previous timestamp notice to
  # help with quick, minimalist profiling.
  # @param production [Boolean] set to true if this timestamp notice is
  #   to be recorded when running in :production environment
  # @param log [Boolean] when false, will not write to any logger; when true, will write to a log
  # @return [NilClass] nil
  # @example Basic use
  #   def hello
  #     Loba.timestamp
  #   end
  #   #=> [TIMESTAMP] #=0001, diff=0.000463, at=1451615389.505411, in=/path/to/file.rb:2:in 'hello'
  # @example Forced to output when in production environment
  #   def hello
  #     Loba.ts production: true # Loba.ts is a shorthand alias for Loba.timestamp
  #   end
  #   #=> [TIMESTAMP] #=0001, diff=0.000463, at=1451615389.505411, in=/path/to/file.rb:2:in 'hello'
  # @example Forced to output to log in addition to $stdout
  #   def hello
  #     Loba.timestamp log: true
  #   end
  #   #=> [TIMESTAMP] #=0001, diff=0.000463, at=1451615389.505411, in=/path/to/file.rb:2:in 'hello'
  def timestamp(production: false, log: false) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    return unless Internal::Platform.logging_allowed?(production)

    # NOTE: while tempting, memoizing loba_logger can lead to surprises if
    #   Rails presence isn't constant
    loba_logger = Internal::Platform.logger(logdev: $stdout)

    begin
      stats = Internal::TimeKeeper.instance.ping
      loba_logger.call(
        # 60: light_black / grey
        "#{Rainbow('[TIMESTAMP]').black.bg(60)}" \
        "#{Rainbow(' #=').yellow.bg(:default)}" \
        "#{format('%04d', stats[:number])}" \
        "#{Rainbow(', diff=').yellow}" \
        "#{format('%.6f', stats[:change])}" \
        "#{Rainbow(', at=').yellow}" \
        "#{format('%.6f', stats[:now].round(6).to_f)}" \
        "#{Rainbow("    \t(in #{caller(1..1).first})").color(60)}", # warning: nested interpolation
        !!log
      )
    rescue StandardError => e
      loba_logger.call Rainbow("[TIMESTAMP] #=FAIL, in=#{caller(1..1).first}, err=#{e}").red
    end

    nil
  end
  module_function :timestamp

  # Shorthand alias for Loba.timestamp.
  # @!method ts(production: false, log: false)
  alias ts timestamp
  module_function :ts
end
