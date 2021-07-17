require_relative 'loba_class'

RSpec.describe Loba do
  it 'has a version number' do
    expect(Loba::VERSION).not_to be nil
  end

  describe 'Platform module methods' do
    it 'cannot be called directly as part of Loba' do
      test_class = Class.new(LobaClass) do
        def hello
          Loba.rails?
        end
      end
      expect { test_class.new.hello }.to raise_error NameError
    end

    it 'can be called if fully namespaced' do
      test_class = Class.new(LobaClass) do
        def hello
          Loba::Internal::Platform.rails?
        end
      end
      expect { test_class.new.hello }.not_to raise_error
    end
  end
end
