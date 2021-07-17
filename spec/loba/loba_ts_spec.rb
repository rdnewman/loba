require_relative 'loba_class'

RSpec.describe Loba, '.ts' do
  before { LobaSpecSupport::OutputControl.suppress! }

  after { LobaSpecSupport::OutputControl.restore! }

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

  it 'writes to STDOUT' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts
      end
    end
    expect { test_class.new.hello }.to output(/\[TIMESTAMP\]/).to_stdout
  end

  it 'write to STDOUT when invoked as Loba.timestamp' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.timestamp
      end
    end
    expect { test_class.new.hello }.to output(/\[TIMESTAMP\]/).to_stdout
  end

  it 'for true argument, raises ArgumentError' do
    # completes deprecation from v0.3.0
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts(true)
      end
    end
    expect { test_class.new.hello }.to raise_error ArgumentError
  end

  it 'for false argument, raises ArgumentError' do
    # completes deprecation from v0.3.0
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts(false)
      end
    end
    expect { test_class.new.hello }.to raise_error ArgumentError
  end

  it 'when argument given as Hash, will not output any error' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts({})
      end
    end
    expect { test_class.new.hello }.not_to output.to_stderr
  end

  it 'for unrecognized argument, will not output an error' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts []
      end
    end
    expect { test_class.new.hello }.not_to output.to_stderr
  end
end
