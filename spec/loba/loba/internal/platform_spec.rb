require 'logger'

RSpec.describe Loba::Internal::Platform do
  describe '.logging_allowed?' do
    it '.logger_allowed? is true when force_true is true' do
      expect(described_class.logging_allowed?(true)).to be true
    end

    context 'when in Rails,' do
      it 'if not in production environment, returns true' do
        mocked_rails = double # verifying double impossible w/o Rails defined
        allow(mocked_rails).to receive(:env).and_return(double)
        allow(mocked_rails.env).to receive(:production?).and_return(false)
        stub_const('Rails', mocked_rails)

        expect(described_class.logging_allowed?).to be true
      end

      it 'if in production environment, returns false' do
        mocked_rails = double
        allow(mocked_rails).to receive(:env).and_return(double)
        allow(mocked_rails.env).to receive(:production?).and_return(true)
        stub_const('Rails', mocked_rails)

        expect(described_class.logging_allowed?).to be false
      end

      it 'if checking for production environment throws an error, returns true' do
        mocked_rails = double
        allow(mocked_rails).to receive(:env).and_return(double)
        allow(mocked_rails.env).to receive(:production?).and_raise('mock failure')
        stub_const('Rails', mocked_rails)

        expect(described_class.logging_allowed?).to be true
      end
    end
  end

  describe '.writer' do
    context 'when not in Rails' do
      before { hide_const('Rails') }

      it '.writer provides a Proc' do
        options = Loba::Internal::Options.new(log: false)
        expect(described_class.writer(options: options)).to be_a(Proc)
      end

      describe 'the Proc from .writer' do
        it 'writes intended output to STDOUT' do
          options = Loba::Internal::Options.new(log: false)
          writer = described_class.writer(options: options)

          expect { writer.call('test') }.to output(/test/).to_stdout
        end

        it 'does not raise an error when logging is not forced' do
          # indirect test: assumption is that if it attempted to call Rails.logger it
          # would raise an error because Rails is not available
          options = Loba::Internal::Options.new(log: false)
          writer = described_class.writer(options: options)
          expect do
            LobaSpecSupport::OutputControl.suppress!
            writer.call('test')
            LobaSpecSupport::OutputControl.restore!
          end.not_to raise_error
        end

        it 'does not raise an error when logging is forced' do
          suppress_stdout_logging_display

          # indirect test: assumption is that if it attempted to call Rails.logger it
          # would raise an error because Rails is not available
          options = Loba::Internal::Options.new(log: true)
          writer = described_class.writer(options: options)

          expect do
            LobaSpecSupport::OutputControl.suppress!
            writer.call('test')
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
          options = Loba::Internal::Options.new(log: false)
          described_class.writer(options: options).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to be_empty
        end

        it 'writes intended output to STDOUT' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          options = Loba::Internal::Options.new(log: false)
          expect do
            described_class.writer(options: options).call('test')
          end.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .writer' do
        it 'writes to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          LobaSpecSupport::OutputControl.suppress!
          options = Loba::Internal::Options.new(log: true)
          described_class.writer(options: options).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to end_with("test\n")
        end

        it 'writes intended output to STDOUT' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          options = Loba::Internal::Options.new(log: true)
          expect do
            described_class.writer(options: options).call('test')
          end.to output(/test/).to_stdout
        end
      end
    end

    describe 'when in Rails, with logging defined, and in production,' do
      describe 'when not forcing logging, the Proc from .writer' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          LobaSpecSupport::OutputControl.suppress!
          options = Loba::Internal::Options.new(log: false)
          described_class.writer(options: options).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to be_empty
        end

        it 'writes intended output to STDOUT' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          options = Loba::Internal::Options.new(log: false)
          expect do
            described_class.writer(options: options).call('test')
          end.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .writer' do
        it 'writes to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          LobaSpecSupport::OutputControl.suppress!
          options = Loba::Internal::Options.new(log: true)
          described_class.writer(options: options).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to end_with("test\n")
        end

        it 'writes intended output to STDOUT' do
          mocked_logger_output = StringIO.new
          mocked_logger = mock_rails_logger(present: true, output: mocked_logger_output)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          options = Loba::Internal::Options.new(log: true)
          expect do
            described_class.writer(options: options).call('test')
          end.to output(/test/).to_stdout
        end
      end
    end

    describe 'when in Rails, without logging defined, and not in production,' do
      describe 'when not forcing logging, the Proc from .writer' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          mocked_rails = mock_rails(production: false, logger: mocked_logger)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          options = Loba::Internal::Options.new(log: false)
          described_class.writer(options: options).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails.logger).not_to have_received(:debug)
        end

        it 'writes intended output to STDOUT' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          options = Loba::Internal::Options.new(log: false)
          expect do
            described_class.writer(options: options).call('test')
          end.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .writer' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          mocked_rails = mock_rails(production: false, logger: mocked_logger)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          options = Loba::Internal::Options.new(log: true)
          described_class.writer(options: options).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails.logger).not_to have_received(:debug)
        end

        it 'writes intended output to STDOUT' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

          options = Loba::Internal::Options.new(log: true)
          expect do
            described_class.writer(options: options).call('test')
          end.to output(/test/).to_stdout
        end
      end
    end

    describe 'when in Rails, without logging defined, and in production,' do
      describe 'when not forcing logging, the Proc from .writer' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          mocked_rails = mock_rails(production: true, logger: mocked_logger)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          options = Loba::Internal::Options.new(log: false)
          described_class.writer(options: options).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails.logger).not_to have_received(:debug)
        end

        it 'writes intended output to STDOUT' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

          options = Loba::Internal::Options.new(log: false)
          expect do
            described_class.writer(options: options).call('test')
          end.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .writer' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          mocked_rails = mock_rails(production: true, logger: mocked_logger)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          options = Loba::Internal::Options.new(log: false)
          described_class.writer(options: options).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails.logger).not_to have_received(:debug)
        end

        it 'writes intended output to STDOUT' do
          mocked_logger = mock_rails_logger(present: false, output: nil)
          stub_const('Rails', mock_rails(production: true, logger: mocked_logger))
          options = Loba::Internal::Options.new(log: false)
          writer = described_class.writer(options: options)

          expect { writer.call('test') }.to output(/test/).to_stdout
        end
      end
    end
  end

  describe 'when :out' do
    it 'is not specified, defaults to output to $stdout' do
      hide_const('Rails')
      options = Loba::Internal::Options.new
      writer = described_class.writer(options: options)

      expect { writer.call('test') }.to output(/test/).to_stdout
    end

    it 'is set to `true`, outputs to $stdout' do
      hide_const('Rails')
      options = Loba::Internal::Options.new(out: true)
      writer = described_class.writer(options: options)

      expect { writer.call('test') }.to output(/test/).to_stdout
    end

    it 'is set to `false`, does not output anything to $stdout' do
      hide_const('Rails')
      suppress_stdout_logging_display

      options = Loba::Internal::Options.new(out: false)
      writer = described_class.writer(options: options)

      expect { writer.call('test') }.not_to output.to_stdout
    end

    it 'is interpreted as false, outputs nothing' do
      hide_const('Rails')
      suppress_stdout_logging_display

      options = Loba::Internal::Options.new(out: File::NULL)
      writer = described_class.writer(options: options)

      expect { writer.call('test') }.not_to output.to_stdout
    end

    it 'is set to $stderr, outputs to $stdout' do
      hide_const('Rails')
      options = Loba::Internal::Options.new(out: $stderr)
      writer = described_class.writer(options: options)

      expect { writer.call('test') }.to output(/test/).to_stdout
    end

    it 'is set to $stderr, does not output to $stderr' do
      hide_const('Rails')
      options = Loba::Internal::Options.new(out: $stderr)
      writer = described_class.writer(options: options)

      # To avoid displaying any output when the test is run, we to capture
      # stdout when confirming that stderr does not receive any output (using the negated matcher).
      expect { writer.call('test') }.to not_output.to_stderr.and output(/test/).to_stdout
    end

    it 'is set to true, but logging to $stdout, will not use puts to output to $stdout' do
      hide_const('Rails')
      suppress_stdout_logging_display

      options = Loba::Internal::Options.new(log: true, logdev: $stdout, out: true)
      expect { described_class.writer(options: options).call('test') }.not_to output.to_stdout
    end
  end

  describe 'internal logger' do
    context 'when in Rails' do
      it 'is not used' do
        mocked_logger = mock_rails_logger(present: true, output: StringIO.new)
        mocked_rails = mock_rails(production: false, logger: mocked_logger)
        stub_const('Rails', mocked_rails)

        allow(Loba::Internal::Platform::Formatter).to receive(:new).and_call_original

        options = Loba::Internal::Options.new(log: true)

        LobaSpecSupport::OutputControl.suppress!
        described_class.writer(options: options).call('test')
        LobaSpecSupport::OutputControl.restore!

        expect(Loba::Internal::Platform::Formatter).not_to have_received(:new)
      end
    end

    context 'when not in Rails' do
      it 'is used' do
        hide_const('Rails')

        allow(Loba::Internal::Platform::Formatter).to receive(:new).and_call_original

        options = Loba::Internal::Options.new(log: true) #, logdev: logdev)

        LobaSpecSupport::OutputControl.suppress!
        described_class.writer(options: options).call('test')
        LobaSpecSupport::OutputControl.restore!

        expect(Loba::Internal::Platform::Formatter).to have_received(:new)
      end
    end
  end

  RSpec::Matchers.define_negated_matcher :not_output, :output

  def mock_rails_logger(present:, output:)
    mock_rails_logger_class = Class.new(Logger) { def present?; end }
    mock_logger = mock_rails_logger_class.new(output)
    allow(mock_logger).to receive(:present?).and_return(!!present)
    allow(mock_logger).to receive(:debug).and_call_original

    mock_logger
  end

  def mock_rails(production:, logger: nil)
    mock_rails = double # verifying double impossible w/o Rails defined
    allow(mock_rails).to receive_messages(env: double, logger: logger)
    allow(mock_rails.env).to receive(:production?).and_return(production)

    mock_rails
  end

  def suppress_stdout_logging_display
    mock_logger = instance_double(Logger)
    allow(mock_logger).to receive(:debug).and_return(nil)
    allow(Logger).to receive(:new).and_return(mock_logger)

    nil
  end
end
