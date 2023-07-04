RSpec.describe Loba::Internal::Platform do
  subject(:platform) { described_class }

  it '.logger_ok? is true when force_true is true' do
    expect(platform.logging_ok?(true)).to be true
  end

  it '.logger provides a Proc' do
    expect(platform.logger).to be_a(Proc)
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

  context 'when not in Rails,' do
    before { hide_const('Rails') } # just to be sure

    it '.rails? is false' do
      expect(platform.rails?).to be false
    end

    it '.logging_ok? is true' do
      expect(platform.logging_ok?).to be true
    end

    it 'the Proc from .logger writes intended output to STDOUT' do
      expect { platform.logger.call('test') }.to output(/test/).to_stdout
    end

    it 'the Proc from .logger does not write to Rails.logger' do
      mock_rails = class_double(LobaSpecSupport::MockRails::Base)
      allow(mock_rails).to receive(:logger)

      LobaSpecSupport::OutputControl.suppress!
      platform.logger.call('test')
      expect(mock_rails).not_to have_received(:logger)
      LobaSpecSupport::OutputControl.restore!
    end
  end

  context 'when in Rails,' do
    let(:mock_rails) { LobaSpecSupport::MockRails::Base }

    before do
      stub_const('Rails', mock_rails)
    end

    it '.rails? is true' do
      expect(platform.rails?).to be true
    end

    it 'if checking for production environment throws an error, .logging_ok? is true' do
      allow(mock_rails)
        .to receive(:env).and_return(LobaSpecSupport::MockRails::MockEnvProduction.new)
      allow(mock_rails.env).to receive(:production?).and_raise('mock failure')

      expect(platform.logging_ok?).to be true
    end

    context 'with logging defined,' do
      let(:mock_rails) { LobaSpecSupport::MockRails::LoggingDefined }

      before do
        allow(mock_rails)
          .to receive(:env).and_return(LobaSpecSupport::MockRails::MockEnvNonproduction.new)
      end

      it 'the Proc from .logger does not write to STDOUT' do
        expect { platform.logger.call('test') }.not_to output.to_stdout
      end

      it 'the Proc from .logger writes to Rails.logger.debug' do
        logging = object_double(mock_rails.logger)
        allow(mock_rails).to receive(:logger).and_return(logging)
        allow(logging).to receive(:debug)
        allow(logging).to receive(:present?).and_return(true)

        platform.logger.call('test')
        expect(logging).to have_received(:debug)
      end

      it 'Rails.logger.debug shows the intended output' do
        platform.logger.call('test')
        expect(mock_rails.mocked_output.string).to end_with("test\n")
      end

      describe 'when not in production,' do
        it '.logging_ok? is true' do
          expect(platform.logging_ok?).to be true
        end
      end

      context 'when in production,' do
        before do
          allow(mock_rails)
            .to receive(:env).and_return(LobaSpecSupport::MockRails::MockEnvProduction.new)
        end

        it '.logging_ok? is false' do
          expect(platform.logging_ok?).to be false
        end
      end
    end

    context 'with logging not defined,' do
      let(:mock_rails) { LobaSpecSupport::MockRails::LoggingUndefined }

      before do
        allow(mock_rails)
          .to receive(:env).and_return(LobaSpecSupport::MockRails::MockEnvNonproduction.new)
      end

      it 'the Proc from .logger writes intended output to STDOUT' do
        expect { platform.logger.call('test') }.to output(/test/).to_stdout
      end

      it 'the Proc from .logger does not write to Rails.logger' do
        logging = object_double(mock_rails.logger)
        allow(mock_rails).to receive(:logger).and_return(logging)
        allow(logging).to receive(:debug)
        allow(logging).to receive(:present?).and_return(false)

        LobaSpecSupport::OutputControl.suppress!
        platform.logger.call('test')
        expect(logging).not_to have_received(:debug)
        LobaSpecSupport::OutputControl.restore!
      end

      describe 'when not in production,' do
        it '.logging_ok? is true' do
          expect(platform.logging_ok?).to be true
        end
      end

      context 'when in production,' do
        before do
          allow(mock_rails)
            .to receive(:env).and_return(LobaSpecSupport::MockRails::MockEnvProduction.new)
        end

        it '.logging_ok? is false' do
          expect(platform.logging_ok?).to be false
        end
      end
    end
  end
end
