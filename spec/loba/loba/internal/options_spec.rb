RSpec.describe Loba::Internal::Options do
  describe 'on instantiation,' do
    describe ':log' do
      it 'can be true' do
        options = described_class.new(log: true)
        expect(options.log).to be true
      end

      it 'can be false' do
        options = described_class.new(log: false)
        expect(options.log).to be false
      end

      it 'can infer true' do
        options = described_class.new(log: 'weird string')
        expect(options.log).to be true
      end

      it 'can infer false' do
        options = described_class.new(log: 0)
        expect(options.log).to be false
      end
    end

    describe ':logger' do
      it 'can be nil' do
        options = described_class.new(logger: nil)
        expect(options.logger).to be_nil
      end

      it 'as nil, and :log not specified, #log will be false' do
        options = described_class.new(logger: nil)
        expect(options.log).to be false
      end

      it 'can be a basic Ruby logger' do
        logger = Logger.new($stdout)
        options = described_class.new(logger: logger)
        expect(options.logger).to be_a Logger
      end

      it 'when valid and :log is not specified, #log will be true' do
        logger = Logger.new($stdout)
        options = described_class.new(logger: logger)
        expect(options.log).to be true
      end

      it 'when not nil, must be a ::Logger' do
        expect { described_class.new(logger: "this ain't right") }
          .to raise_error Loba::InvalidLoggerOptionError
      end
    end

    describe ':logdev' do
      it 'can be nil' do
        options = described_class.new(logdev: nil)
        expect(options.logdev).to be_nil
      end

      it 'can be a String' do
        options = described_class.new(logdev: 'logdev')
        expect(options.logdev).to eq 'logdev'
      end

      it 'can be an IO object' do
        options = described_class.new(logdev: $stderr)
        expect(options.logdev).to be $stderr
      end

      it 'can be File::NULL' do
        options = described_class.new(logdev: File::NULL)
        expect(options.logdev).to be File::NULL
      end

      it 'when not nil or File::NULL, must be a String or an IO object' do
        expect { described_class.new(logdev: StringIO) } # StringIO is not a subclass of IO
          .to raise_error Loba::InvalidLogdevOptionError
      end
    end

    describe ':out' do
      it 'treats true as true' do
        options = described_class.new(out: true)
        expect(options.out).to be true
      end

      it 'treats false as false' do
        options = described_class.new(out: false)
        expect(options.out).to be false
      end

      it 'treats nil as false' do
        options = described_class.new(out: nil)
        expect(options.out).to be false
      end

      it 'treats File::NULL as false' do
        options = described_class.new(out: File::NULL)
        expect(options.out).to be false
      end

      it 'treats $stderr as simply true' do
        options = described_class.new(out: $stderr)
        expect(options.out).to be true
      end

      it 'treats a StringIO object as simply true' do
        io = StringIO.new
        options = described_class.new(out: io)
        expect(options.out).to be true
      end

      it 'when not nil, true, or false, must be an Integer, a String, ' \
         'an IO object, or a StringIO object' do
        expect { described_class.new(out: []) }
          .to raise_error Loba::InvalidOutOptionError
      end

      it 'can be true when not logging to $stdout' do
        options = described_class.new(logdev: $stdout, out: true) # :log defaults to false
        expect(options.out).to be true
      end

      it 'is always false when logging to $stdout' do
        options = described_class.new(log: true, logdev: $stdout, out: true)
        expect(options.out).to be false
      end
    end
  end

  describe 'assignment using' do
    describe '#log=' do
      it 'succeeds' do
        options = described_class.new(log: true)

        options.log = :off
        expect(options.log).to be false
      end
    end

    describe '#logger=' do
      it 'succeeds' do
        options = described_class.new(logger: nil)

        logger = Logger.new($stdout)
        options.logger = logger
        expect(options.logger).to be logger
      end
    end

    describe '#logdev=' do
      it 'succeeds' do
        options = described_class.new(logdev: nil)

        options.logdev = File::NULL
        expect(options.logdev).to be File::NULL
      end
    end

    describe '#out=' do
      it 'succeeds' do
        options = described_class.new(out: nil)

        io = StringIO.new
        options.out = io
        expect(options.out).to be true
      end
    end
  end
end
