RSpec.describe Loba::Internal::Settings do
  describe 'on instantiation,' do
    describe ':log' do
      it 'can be true' do
        settings = described_class.new(log: true)
        expect(settings.log).to be true
      end

      it 'can be false' do
        settings = described_class.new(log: false)
        expect(settings.log).to be false
      end

      it 'can infer true' do
        settings = described_class.new(log: 'weird string')
        expect(settings.log).to be true
      end

      it 'can infer false' do
        settings = described_class.new(log: 0)
        expect(settings.log).to be false
      end
    end

    describe ':logger' do
      it 'can be nil' do
        settings = described_class.new(logger: nil)
        expect(settings.logger).to be_nil
      end

      it 'can be a basic Ruby logger' do
        logger = Logger.new($stdout)
        settings = described_class.new(logger: logger)
        expect(settings.logger).to be_a Logger
      end

      it 'when not nil, must be a ::Logger' do
        expect { described_class.new(logger: "this ain't right") }
          .to raise_error Loba::InvalidLoggerOptionError
      end
    end

    describe ':logdev' do
      it 'can be nil' do
        settings = described_class.new(logdev: nil)
        expect(settings.logdev).to be_nil
      end

      it 'can be a String' do
        settings = described_class.new(logdev: 'logdev')
        expect(settings.logdev).to eq 'logdev'
      end

      it 'can be an IO object' do
        settings = described_class.new(logdev: $stderr)
        expect(settings.logdev).to be $stderr
      end

      it 'can be File::NULL' do
        settings = described_class.new(logdev: File::NULL)
        expect(settings.logdev).to be File::NULL
      end

      it 'when not nil or File::NULL, must be a String or an IO object' do
        expect { described_class.new(logdev: StringIO) } # StringIO is not a subclass of IO
          .to raise_error Loba::InvalidLogdevOptionError
      end
    end

    describe ':out' do
      it 'treats true as true' do
        settings = described_class.new(out: true)
        expect(settings.out).to be true
      end

      it 'treats false as false' do
        settings = described_class.new(out: false)
        expect(settings.out).to be false
      end

      it 'treats nil as false' do
        settings = described_class.new(out: nil)
        expect(settings.out).to be false
      end

      it 'treats File::NULL as false' do
        settings = described_class.new(out: File::NULL)
        expect(settings.out).to be false
      end

      it 'treats $stderr as simply true' do
        settings = described_class.new(out: $stderr)
        expect(settings.out).to be true
      end

      it 'treats a StringIO object as simply true' do
        io = StringIO.new
        settings = described_class.new(out: io)
        expect(settings.out).to be true
      end

      it 'when not nil, true, or false, must be an Integer, a String, ' \
         'an IO object, or a StringIO object' do
        expect { described_class.new(out: []) }
          .to raise_error Loba::InvalidOutOptionError
      end

      it 'can be true when not logging to $stdout' do
        settings = described_class.new(logdev: $stdout, out: true) # :log defaults to false
        expect(settings.out).to be true
      end

      it 'is always false when logging to $stdout' do
        settings = described_class.new(log: true, logdev: $stdout, out: true)
        expect(settings.out).to be false
      end
    end
  end

  describe '#log,' do
    it 'when :log not specified and :logger is nil, #log will be false' do
      settings = described_class.new(logger: nil)
      expect(settings.log).to be false
    end

    it 'when :log is not specified and :logger is valid, will be true' do
      settings = described_class.new(logger: Logger.new($stdout))
      expect(settings.log).to be true
    end
  end

  describe '#logger,' do
    it 'when in Rails and not specified and not logging, will be nil' do
      mocked_logger = mock_rails_logger(present: true, output: StringIO.new)
      stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

      settings = described_class.new
      expect(settings.logger).to be_nil
    end

    it 'when in Rails and not specified but are logging, will be the Rails logger' do
      mocked_logger = mock_rails_logger(present: true, output: StringIO.new)
      stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

      settings = described_class.new(log: true)
      expect(settings.logger).to eq mocked_logger
    end
  end

  describe '#enabled,' do
    context 'within Rails' do
      context 'and not in a production environment,' do
        it 'is true' do
          stub_const('Rails', mock_rails(production: false, logger: nil))

          settings = described_class.new
          expect(settings.enabled?).to be true
        end
      end

      context 'and in a production environment,' do
        it 'is false when not forced' do
          stub_const('Rails', mock_rails(production: true, logger: nil))

          settings = described_class.new
          expect(settings.enabled?).to be false
        end

        it 'is true when forced' do
          stub_const('Rails', mock_rails(production: true, logger: nil))

          settings = described_class.new(production: true)
          expect(settings.enabled?).to be true
        end
      end
    end

    context 'without Rails,' do
      it 'is true' do
        hide_const('Rails')

        settings = described_class.new
        expect(settings.enabled?).to be true
      end
    end
  end

  describe '#disabled,' do
    context 'within Rails' do
      context 'and not in a production environment,' do
        it 'is false' do
          stub_const('Rails', mock_rails(production: false, logger: nil))

          settings = described_class.new
          expect(settings.disabled?).to be false
        end
      end

      context 'and in a production environment,' do
        it 'is true when not forced' do
          stub_const('Rails', mock_rails(production: true, logger: nil))

          settings = described_class.new
          expect(settings.disabled?).to be true
        end

        it 'is false when forced' do
          stub_const('Rails', mock_rails(production: true, logger: nil))

          settings = described_class.new(production: true)
          expect(settings.disabled?).to be false
        end
      end
    end

    context 'without Rails,' do
      it 'is false' do
        hide_const('Rails')

        settings = described_class.new
        expect(settings.disabled?).to be false
      end
    end
  end
end
