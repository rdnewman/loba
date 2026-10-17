require "securerandom"

module Lba
  module Internal
    # One process's run: every record it writes carries the run's id, and its
    # records share one sink file.
    class Run
      # Fails if anything, even a symlink, is already at the path.
      CREATE_FLAGS = File::WRONLY | File::CREAT | File::EXCL | File::NOFOLLOW
      private_constant :CREATE_FLAGS

      class << self
        # This process's run, created on first use.
        #
        # A forked child inherits this memo; the pid check gives it its own run
        # and file.
        #
        # @return [Run]
        def current
          return @current if @current&.pid == Process.pid

          @current = new
        end
      end

      # @return [String] the run's id: a UTC timestamp, the process id, and eight
      #   random hex digits, e.g. +"20260926T210626Z-894825-b10f3e7a"+
      attr_reader :id

      # @return [Integer] the id of the process that started the run
      attr_reader :pid

      # Starts a run for the current process.
      def initialize
        @pid = Process.pid
        @id = generate_id
        @claimed_paths = []
      end

      # Claims a file for this run's records: creates it, readable and writable
      # only by its owner, the first time it's claimed.
      #
      # A file or symlink already at the path wasn't made by this run (the
      # random part of the id makes the path hard to guess ahead of time), so
      # the path is refused rather than appended to.
      #
      # @param path [String] where the run's file goes
      # @return [Boolean] whether this run created the file at +path+
      def claim_file(path)
        claimed_paths.include?(path) || claim(path)
      end

    private

      attr_reader :claimed_paths

      def claim(path)
        create_exclusively(path)
        claimed_paths << path
        true
      rescue SystemCallError
        false
      end

      # Fails if anything is already at the path, a symlink included.
      def create_exclusively(path)
        File.write(path, "", flags: CREATE_FLAGS, perm: 0o600)
      end

      def generate_id
        timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
        "#{timestamp}-#{pid}-#{SecureRandom.hex(4)}"
      end
    end
  end
end
