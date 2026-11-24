require "open3"
require "rbconfig"
require "tmpdir"

RSpec.describe Loba do
  # A load-time warning shows only once per process, so this spawns one. Ruby's
  # -w includes deprecation warnings, so a recorded value also checks the
  # capture path.
  it "warns nothing under ruby -w, loading and recording a value" do
    Dir.mktmpdir do |dir|
      lib_dir = File.expand_path("../lib", __dir__)
      # Without Bundler, which makes the process several times slower to start.
      environment = { "RUBYOPT" => nil, "LOBA_SINK" => nil }
      script = 'require "loba"; Loba.val(1)'

      output, = Open3.capture2e(
        environment, RbConfig.ruby, "-w", "-I", lib_dir, "-e", script, chdir: dir
      )

      expect(output).to be_empty
    end
  end
end
