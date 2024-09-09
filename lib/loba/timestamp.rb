module Loba # rubocop:disable Style/Documentation
  # Outputs a timestamped notice, useful for quick traces to see the code path.
  # Also does a simple elapsed time check since the previous timestamp notice to
  # help with quick, minimalist profiling.
  # @param production [boolean]
  #   set to +true+ if this timestamp notice is to be recorded
  #   when running in a Rails production environment
  # @param log [boolean]
  #   set to +false+ if no logging is ever wanted
  #   (default when not in Rails and +logger+ is nil);
  #   set to +true+ if logging is always wanted (default when in Rails or
  #   when +logger+ is set or +out+ is false);
  # @param logger [Logger] override logging with specified Ruby Logger
  # @param logdev [nil, String, IO, File::NULL]
  #   custom log device to use (when not in Rails); ignored if +logger+ is set;
  #   must be filename or IO object
  # @param out [boolean]
  #   set to +false+ if console output is to be suppressed
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
  # @note To avoid doubled output, if a non-Rails logger is to be logged to and +logdev+ is
  #   set to +$stdout+, then output will be suppressed (i.e., +settings.out+ is +false+).
  #   Doubled output can still occur; in that case, explicitly use +out: false+.
  def timestamp( # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    production: false,
    log: false,
    logger: nil,
    logdev: nil,
    out: true
  )
    settings = Internal::Settings.new(
      log: log, logger: logger, logdev: logdev, out: out, production: production
    )

    return unless settings.enabled?

    # NOTE: while tempting, memoizing loba_logger can lead to surprises if
    #   Rails presence isn't constant
    writer = Internal::Platform.writer(settings: settings)

    begin
      stats = Internal::TimeKeeper.instance.ping
      writer.call(
        # 60: light_black / grey
        "#{Rainbow('[TIMESTAMP]').black.bg(60)}" \
        "#{Rainbow(' #=').yellow.bg(:default)}" \
        "#{format('%04d', stats[:number])}" \
        "#{Rainbow(', diff=').yellow}" \
        "#{format('%.6f', stats[:change])}" \
        "#{Rainbow(', at=').yellow}" \
        "#{format('%.6f', stats[:now].round(6).to_f)}" \
        "#{Rainbow("    \t(in #{caller(1..1).first})").color(60)}" # warning: nested interpolation
      )
    rescue StandardError => e
      writer.call Rainbow("[TIMESTAMP] #=FAIL, in=#{caller(1..1).first}, err=#{e}").red
    end

    nil
  end
  module_function :timestamp

  # Shorthand alias for Loba.timestamp.
  # @!method ts(production: false, log: false, logger: nil, logdev: nil, out: true)
  alias ts timestamp
  module_function :ts
end
