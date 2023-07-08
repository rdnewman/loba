require 'logger'

RSpec.describe Loba::Internal::Platform do
  describe '.rails?' do
    context 'when not in Rails' do
      it 'returns false' do
        hide_const('Rails') # just to be sure

        expect(described_class.rails?).to be false
      end
    end

    context 'when in Rails' do
      it 'returns true' do
        stub_const('Rails', double)

        expect(described_class.rails?).to be true
      end
    end

    it 'cannot be called directly as part of Loba' do
      test_class = Class.new do
        def hello
          Loba.rails?
        end
      end
      expect { test_class.new.hello }.to raise_error NameError
    end

    it 'can be called if fully namespaced' do
      test_class = Class.new do
        def hello
          Loba::Internal::Platform.rails?
        end
      end
      expect { test_class.new.hello }.not_to raise_error
    end
  end

  describe '.logging_ok?' do
    it '.logger_ok? is true when force_true is true' do
      expect(described_class.logging_ok?(true)).to be true
    end

    context 'when in Rails,' do
      it 'if not in production environment, returns true' do
        mocked_rails = double # verifying double impossible w/o Rails defined
        allow(mocked_rails).to receive(:env).and_return(double)
        allow(mocked_rails.env).to receive(:production?).and_return(false)
        stub_const('Rails', mocked_rails)

        expect(described_class.logging_ok?).to be true
      end

      it 'if in production environment, returns false' do
        mocked_rails = double
        allow(mocked_rails).to receive(:env).and_return(double)
        allow(mocked_rails.env).to receive(:production?).and_return(true)
        stub_const('Rails', mocked_rails)

        expect(described_class.logging_ok?).to be false
      end

      it 'if checking for production environment throws an error, returns true' do
        mocked_rails = double
        allow(mocked_rails).to receive(:env).and_return(double)
        allow(mocked_rails.env).to receive(:production?).and_raise('mock failure')
        stub_const('Rails', mocked_rails)

        expect(described_class.logging_ok?).to be true
      end
    end
  end

  describe '.logger' do
    context 'when not in Rails' do
      before { hide_const('Rails') }

      it '.logger provides a Proc' do
        expect(described_class.logger).to be_a(Proc)
      end

      describe 'the Proc from .logger' do
        it 'writes intended output to STDOUT' do
          logger = described_class.logger
          expect { logger.call('test') }.to output(/test/).to_stdout
        end

        it 'does not raise an error when logging is not forced' do
          # indirect test: assumption is that if it attempted to call Rails.logger it
          # would raise an error because Rails is not available
          logger = described_class.logger

          expect do
            LobaSpecSupport::OutputControl.suppress!
            logger.call('test')
            LobaSpecSupport::OutputControl.restore!
          end.not_to raise_error
        end

        it 'does not raise an error when logging is forced' do
          # indirect test: assumption is that if it attempted to call Rails.logger it
          # would raise an error because Rails is not available
          logger = described_class.logger

          expect do
            LobaSpecSupport::OutputControl.suppress!
            logger.call('test', true)
            LobaSpecSupport::OutputControl.restore!
          end.not_to raise_error
        end
      end
    end

    describe 'when in Rails, with logging defined, and not in production,' do
      describe 'when not forcing logging, the Proc from .logger' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          LobaSpecSupport::OutputControl.suppress!
          described_class.logger.call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to be_empty
        end

        it 'writes intended output to STDOUT' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          expect { described_class.logger.call('test') }.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .logger' do
        it 'writes to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          LobaSpecSupport::OutputControl.suppress!
          described_class.logger.call('test', true)
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to end_with("test\n")
        end

        it 'writes intended output to STDOUT' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          expect { described_class.logger.call('test', true) }.to output(/test/).to_stdout
        end
      end
    end

    describe 'when in Rails, with logging defined, and in production,' do
      describe 'when not forcing logging, the Proc from .logger' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          LobaSpecSupport::OutputControl.suppress!
          described_class.logger.call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to be_empty
        end

        it 'writes intended output to STDOUT' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          expect { described_class.logger.call('test') }.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .logger' do
        it 'writes to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          LobaSpecSupport::OutputControl.suppress!
          described_class.logger.call('test', true)
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to end_with("test\n")
        end

        it 'writes intended output to STDOUT' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          expect { described_class.logger.call('test', true) }.to output(/test/).to_stdout
        end
      end
    end

    describe 'when in Rails, without logging defined, and not in production,' do
      describe 'when not forcing logging, the Proc from .logger' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          mocked_rails = mock_rails(production: false, logger: mocked_logger)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          described_class.logger.call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails.logger).not_to have_received(:debug)
        end

        it 'writes intended output to STDOUT' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          expect { described_class.logger.call('test') }.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .logger' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          mocked_rails = mock_rails(production: false, logger: mocked_logger)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          described_class.logger.call('test', true)
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails.logger).not_to have_received(:debug)
        end

        it 'writes intended output to STDOUT' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          expect { described_class.logger.call('test', true) }.to output(/test/).to_stdout
        end
      end
    end

    describe 'when in Rails, without logging defined, and in production,' do
      describe 'when not forcing logging, the Proc from .logger' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          mocked_rails = mock_rails(production: true, logger: mocked_logger)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          described_class.logger.call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails.logger).not_to have_received(:debug)
        end

        it 'writes intended output to STDOUT' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          expect { described_class.logger.call('test') }.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .logger' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          mocked_rails = mock_rails(production: true, logger: mocked_logger)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          described_class.logger.call('test', true)
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails.logger).not_to have_received(:debug)
        end

        it 'writes intended output to STDOUT' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          expect { described_class.logger.call('test', true) }.to output(/test/).to_stdout
        end
      end
    end

    def mock_rails_logger(present:, output:)
      mock_rails_logger_class = Class.new(Logger) { def present?; end }
      mock_logger = mock_rails_logger_class.new(output)
      allow(mock_logger).to receive(:present?).and_return(!!present) # rubocop:disable Style/DoubleNegation
      allow(mock_logger).to receive(:debug).and_call_original

      mock_logger
    end

    def mock_rails(production:, logger: nil)
      mock_rails = double # verifying double impossible w/o Rails defined
      allow(mock_rails).to receive(:env).and_return(double)
      allow(mock_rails.env).to receive(:production?).and_return(production)
      allow(mock_rails).to receive(:logger).and_return(logger)

      mock_rails
    end
  end
end
