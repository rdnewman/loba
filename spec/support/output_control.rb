module LobaSpecSupport
  class OutputControl
    def self.suppress!
      @original_stderr = $stderr
      $stderr = File.open(File::NULL, 'w')

      @original_stdout = $stdout
      $stdout = File.open(File::NULL, 'w')
    end

    def self.restore!
      $stderr = @original_stderr
      @original_stderr = nil

      $stdout = @original_stdout
      @original_stdout = nil
    end
  end
end
