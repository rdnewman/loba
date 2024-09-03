require 'logger'

RSpec.describe Loba::Internal::Platform do
  describe '.writer' do
    context 'when not in Rails' do
      before { hide_const('Rails') }

      it '.writer provides a Proc' do
        settings = Loba::Internal::Settings.new(log: false)
        expect(described_class.writer(settings: settings)).to be_a(Proc)
      end

      describe 'the Proc from .writer' do
        it 'writes intended output to STDOUT' do
          settings = Loba::Internal::Settings.new(log: false)
          writer = described_class.writer(settings: settings)

          expect { writer.call('test') }.to output(/test/).to_stdout
        end

        it 'does not raise an error when logging is not forced' do
          # indirect test: assumption is that if it attempted to call Rails.logger it
          # would raise an error because Rails is not available
          settings = Loba::Internal::Settings.new(log: false)
          writer = described_class.writer(settings: settings)
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
          settings = Loba::Internal::Settings.new(log: true)
          writer = described_class.writer(settings: settings)

          expect do
            LobaSpecSupport::OutputControl.suppress!
            writer.call('test')
            LobaSpecSupport::OutputControl.restore!
          end.not_to raise_error
        end
      end
    end

    describe 'when in Rails, Rails.logger exists, and not in production,' do
      describe 'when not forcing logging, the Proc from .logger' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          stub_const('Rails', mocked_rails_with_logging(mocked_logger_output))

          LobaSpecSupport::OutputControl.suppress!
          settings = Loba::Internal::Settings.new(log: false)
          described_class.writer(settings: settings).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to be_empty
        end

        it 'writes intended output to STDOUT' do
          stub_const('Rails', mocked_rails_with_logging(StringIO.new))

          settings = Loba::Internal::Settings.new(log: false)
          expect do
            described_class.writer(settings: settings).call('test')
          end.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .writer' do
        it 'writes to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          stub_const('Rails', mocked_rails_with_logging(mocked_logger_output))

          LobaSpecSupport::OutputControl.suppress!
          settings = Loba::Internal::Settings.new(log: true)
          described_class.writer(settings: settings).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to end_with("test\n")
        end

        it 'writes intended output to STDOUT' do
          stub_const('Rails', mocked_rails_with_logging(StringIO.new))

          settings = Loba::Internal::Settings.new(log: true)
          expect do
            described_class.writer(settings: settings).call('test')
          end.to output(/test/).to_stdout
        end
      end

      def mocked_rails_with_logging(output)
        mock_rails(
          production: false,
          logger: mock_rails_logger(present: true, output: output)
        )
      end
    end

    describe 'when in Rails, Rails.logger exists, and in production,' do
      describe 'when not forcing logging, the Proc from .writer' do
        it 'does not write to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          stub_const('Rails', mocked_rails_with_logging(mocked_logger_output))

          LobaSpecSupport::OutputControl.suppress!
          settings = Loba::Internal::Settings.new(log: false, production: true)
          described_class.writer(settings: settings).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to be_empty
        end

        it 'writes intended output to STDOUT' do
          stub_const('Rails', mocked_rails_with_logging(StringIO.new))

          settings = Loba::Internal::Settings.new(log: false, production: true)
          expect do
            described_class.writer(settings: settings).call('test')
          end.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .writer' do
        it 'writes to Rails.logger.debug' do
          mocked_logger_output = StringIO.new
          stub_const('Rails', mocked_rails_with_logging(mocked_logger_output))

          LobaSpecSupport::OutputControl.suppress!
          settings = Loba::Internal::Settings.new(log: true, production: true)
          described_class.writer(settings: settings).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_logger_output.string).to end_with("test\n")
        end

        it 'writes intended output to STDOUT' do
          stub_const('Rails', mocked_rails_with_logging(StringIO.new))

          settings = Loba::Internal::Settings.new(log: true, production: true)
          expect do
            described_class.writer(settings: settings).call('test')
          end.to output(/test/).to_stdout
        end
      end

      def mocked_rails_with_logging(output)
        mock_rails(
          production: true,
          logger: mock_rails_logger(present: true, output: output)
        )
      end
    end

    describe 'when in Rails, but Rails.logger does not exist, and not in production,' do
      describe 'when not forcing logging, the Proc from .writer' do
        it 'does not attempt to write to Rails.logger' do
          mocked_rails = mock_rails(production: false, logger: nil)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          settings = Loba::Internal::Settings.new(log: false)
          described_class.writer(settings: settings).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails).not_to have_received(:logger)
        end

        it 'writes intended output to STDOUT' do
          stub_const('Rails', mock_rails(production: false, logger: nil))

          settings = Loba::Internal::Settings.new(log: false)
          expect do
            described_class.writer(settings: settings).call('test')
          end.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .writer' do
        it 'does not write to Rails.logger' do
          stub_const('Rails', mock_rails(production: false, logger: nil))

          RSpec::Mocks.configuration.allow_message_expectations_on_nil = Rails.logger.nil?
          allow(Rails.logger).to receive(:debug)

          LobaSpecSupport::OutputControl.suppress!
          settings = Loba::Internal::Settings.new(log: true)
          described_class.writer(settings: settings).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(Rails.logger).not_to have_received(:debug)
        end

        it 'writes to the fallback logger' do
          stub_const('Rails', mock_rails(production: false, logger: nil))

          settings = Loba::Internal::Settings.new(log: true)
          allow(settings.logger).to receive(:debug)

          LobaSpecSupport::OutputControl.suppress!
          described_class.writer(settings: settings).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(settings.logger).to have_received(:debug)
        end

        it 'writes intended output to STDOUT' do
          stub_const('Rails', mock_rails(production: false, logger: nil))
          suppress_stdout_logging_display

          settings = Loba::Internal::Settings.new(log: true)
          expect do
            described_class.writer(settings: settings).call('test')
          end.to output(/test/).to_stdout
        end
      end
    end

    describe 'when in Rails, but Rails.logger does not exist, and in production,' do
      describe 'when not forcing logging, the Proc from .writer' do
        it 'does not attempt to write to Rails.logger' do
          mocked_rails = mock_rails(production: true, logger: nil)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          settings = Loba::Internal::Settings.new(log: false, production: true)
          described_class.writer(settings: settings).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails).not_to have_received(:logger)
        end

        it 'writes intended output to STDOUT' do
          stub_const('Rails', mock_rails(production: true, logger: nil))

          settings = Loba::Internal::Settings.new(log: false, production: true)
          expect do
            described_class.writer(settings: settings).call('test')
          end.to output(/test/).to_stdout
        end
      end

      describe 'when forcing logging, the Proc from .writer' do
        it 'does not attempt to write to Rails.logger' do
          mocked_rails = mock_rails(production: true, logger: nil)
          stub_const('Rails', mocked_rails)

          LobaSpecSupport::OutputControl.suppress!
          settings = Loba::Internal::Settings.new(log: false, production: true)
          described_class.writer(settings: settings).call('test')
          LobaSpecSupport::OutputControl.restore!

          expect(mocked_rails).not_to have_received(:logger)
        end

        it 'writes intended output to STDOUT' do
          stub_const('Rails', mock_rails(production: true, logger: nil))
          settings = Loba::Internal::Settings.new(log: false, production: true)
          writer = described_class.writer(settings: settings)

          expect { writer.call('test') }.to output(/test/).to_stdout
        end
      end
    end
  end

  describe 'when :out' do
    it 'is not specified, defaults to output to $stdout' do
      hide_const('Rails')
      settings = Loba::Internal::Settings.new
      writer = described_class.writer(settings: settings)

      expect { writer.call('test') }.to output(/test/).to_stdout
    end

    it 'is set to `true`, outputs to $stdout' do
      hide_const('Rails')
      settings = Loba::Internal::Settings.new(out: true)
      writer = described_class.writer(settings: settings)

      expect { writer.call('test') }.to output(/test/).to_stdout
    end

    it 'is set to `false`, does not output anything to $stdout' do
      hide_const('Rails')
      suppress_stdout_logging_display

      settings = Loba::Internal::Settings.new(out: false)
      writer = described_class.writer(settings: settings)

      expect { writer.call('test') }.not_to output.to_stdout
    end

    it 'is interpreted as false, outputs nothing' do
      hide_const('Rails')
      suppress_stdout_logging_display

      settings = Loba::Internal::Settings.new(out: File::NULL)
      writer = described_class.writer(settings: settings)

      expect { writer.call('test') }.not_to output.to_stdout
    end

    it 'is set to $stderr, outputs to $stdout' do
      hide_const('Rails')
      settings = Loba::Internal::Settings.new(out: $stderr)
      writer = described_class.writer(settings: settings)

      expect { writer.call('test') }.to output(/test/).to_stdout
    end

    it 'is set to $stderr, does not output to $stderr' do
      hide_const('Rails')
      settings = Loba::Internal::Settings.new(out: $stderr)
      writer = described_class.writer(settings: settings)

      # To avoid displaying any output when the test is run, we to capture
      # stdout when confirming that stderr does not receive any output (using the negated matcher).
      expect { writer.call('test') }.to not_output.to_stderr.and output(/test/).to_stdout
    end

    it 'is set to true, but logging to $stdout, will not use puts to output to $stdout' do
      hide_const('Rails')
      suppress_stdout_logging_display

      settings = Loba::Internal::Settings.new(log: true, logdev: $stdout, out: true)
      expect { described_class.writer(settings: settings).call('test') }.not_to output.to_stdout
    end
  end

  describe 'internal logger' do
    context 'when in Rails' do
      it 'is not used' do
        mocked_logger = mock_rails_logger(present: true, output: StringIO.new)
        stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

        allow(Loba::Internal::Platform::Formatter).to receive(:new).and_call_original

        settings = Loba::Internal::Settings.new(log: true)

        LobaSpecSupport::OutputControl.suppress!
        described_class.writer(settings: settings).call('test')
        LobaSpecSupport::OutputControl.restore!

        expect(Loba::Internal::Platform::Formatter).not_to have_received(:new)
      end
    end

    context 'when not in Rails' do
      it 'is used' do
        hide_const('Rails')
        suppress_stdout_logging_display

        allow(Loba::Internal::Platform::Formatter).to receive(:new).and_call_original
        settings = Loba::Internal::Settings.new(log: true)

        LobaSpecSupport::OutputControl.suppress!
        described_class.writer(settings: settings).call('test')
        LobaSpecSupport::OutputControl.restore!

        expect(Loba::Internal::Platform::Formatter).to have_received(:new)
      end
    end
  end

  RSpec::Matchers.define_negated_matcher :not_output, :output

  def suppress_stdout_logging_display
    mock_logger = instance_double(Logger)
    allow(mock_logger).to receive(:debug).and_return(nil)
    allow(Logger).to receive(:new).and_return(mock_logger)

    nil
  end
end
