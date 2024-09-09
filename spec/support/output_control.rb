module LobaSpecSupport
  class OutputControl
    def self.suppress!
      restore! # ensure back in original state

      @original_stdout = $stdout
      $stdout = File.open(File::NULL, 'w')
    end

    def self.restore!
      return unless defined?(@original_stdout)
      return if @original_stdout.nil?

      $stdout = @original_stdout
      @original_stdout = nil
    end

    def self.redirect!(path)
      # BEST USE in diagnosing specs:
      #   begin
      #     LobaSpecSupport::OutputControl.redirect!('./filename.ext')
      #     # your code to generate output goes here
      #   ensure
      #     LobaSpecSupport::OutputControl.suppress! # or restore!
      #   end

      restore! # ensure back in original state

      @original_stdout = $stdout
      $stdout = File.open(path, 'w')
    end

    def self.capture!
      # BEST USE in dignosing specs:
      #   my_string_var = LobaSpecSupport::OutputControl.capture! { puts "hello"; puts "goodbye" }

      return unless block_given?

      stdout_before = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = stdout_before
    end
  end
end
