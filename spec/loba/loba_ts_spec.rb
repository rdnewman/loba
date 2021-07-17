require_relative 'loba_class'

RSpec.describe Loba, '.ts' do
  before do
    LobaSpecSupport::OutputControl.suppress!
  end

  after do
    LobaSpecSupport::OutputControl.restore!
  end

  it 'can be called as Loba.ts' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts
      end
    end
    expect { test_class.new.hello }.not_to raise_error
  end

  it 'can be called as Loba.timestamp' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.timestamp
      end
    end
    expect { test_class.new.hello }.not_to raise_error
  end

  it 'cannot be called as ts only' do
    test_class = Class.new(LobaClass) do
      def hello
        ts
      end
    end
    expect { test_class.new.hello }.to raise_error NameError
  end

  it 'can be called from instance methods' do
    expect { LobaClass.new.base_ts }.not_to raise_error
  end

  it 'can be called from class methods' do
    expect { LobaClass.classbase_ts }.not_to raise_error
  end

  it 'can write to STDOUT' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts
      end
    end
    expect { test_class.new.hello }.to output(/\[TIMESTAMP\]/).to_stdout
  end

  it 'can write to STDOUT when invoked as Loba.timestamp' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.timestamp
      end
    end
    expect { test_class.new.hello }.to output(/\[TIMESTAMP\]/).to_stdout
  end

  it 'will mark true argument as deprecated' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts(true)
      end
    end
    expected_text = 'DEPRECATION WARNING: use {:production => true} instead to ' \
                    "indicate notice is enabled in production\n"
    expect { test_class.new.hello }.to output(expected_text).to_stderr
  end

  it 'will mark false argument as deprecated' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts(false)
      end
    end
    expected_text = 'DEPRECATION WARNING: use {:production => false} instead to ' \
                    "indicate notice is disabled in production\n"
    expect { test_class.new.hello }.to output(expected_text).to_stderr
  end

  it 'will not mark options argument as deprecated when given as a hash' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts({})
      end
    end
    expect { test_class.new.hello }.not_to output.to_stderr
  end

  it 'will mark unrecognized argument as deprecated' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts []
      end
    end
    expected_text = 'DEPRECATION WARNING: use {:production => false} instead to ' \
                    "indicate notice is disabled in production\n"
    expect { test_class.new.hello }.to output(expected_text).to_stderr
  end
end
