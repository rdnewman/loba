# require 'profile'
require 'ruby-prof'

RSpec.describe Loba do
  # describe 'profiling', focus: true do
  ### Use the above line (and comment out one below) to run performance checks
  describe 'profiling', skip: 'Ignore performance analysis during normal testing' do
    # rubocop:disable RSpec/InstanceVariable

    before do
      @profile = RubyProf::Profile.new
      @profile.exclude_methods!(Integer, :times)
      @profile.start
      @profile.pause
      LobaSpecSupport::OutputControl.suppress!
    end

    after do
      LobaSpecSupport::OutputControl.restore!
      RubyProf::FlatPrinter.new(@profile).print($stdout, min_percent: 0.8)
    end

    def run_profile(number_of_times = 5000)
      return unless block_given?

      number_of_times.times do
        @profile.resume
        yield
        @profile.pause
      end
      @profile.stop
    end

    # rubocop:enable RSpec/InstanceVariable

    it 'Loba.ts' do
      run_profile { described_class.ts }
    end

    it 'Loba.val' do
      _x = 5
      run_profile { described_class.val :_x }
    end
  end
end
