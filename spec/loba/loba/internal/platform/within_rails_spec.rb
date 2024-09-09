RSpec.describe Loba::Internal::Platform::WithinRails do
  context 'when in Rails' do
    context 'and not in production environment' do
      it 'and uses a logger, #logger returns true' do
        mocked_logger = mock_rails_logger(present: true, output: $stdout)
        stub_const('Rails', mock_rails(production: false, logger: mocked_logger))

        expect(described_class.logger?).to be true
      end

      it 'and does not use a logger, #logger returns false' do
        stub_const('Rails', mock_rails(production: false, logger: nil))

        expect(described_class.logger?).to be false
      end

      it '#production? returns false' do
        stub_const('Rails', mock_rails(production: false))

        expect(described_class.production?).to be false
      end
    end

    context 'and in production environment' do
      it 'and uses a logger, #logger returns true' do
        mocked_logger = mock_rails_logger(present: true, output: $stdout)
        stub_const('Rails', mock_rails(production: true, logger: mocked_logger))

        expect(described_class.logger?).to be true
      end

      it 'and does not use a logger, #logger returns true' do
        stub_const('Rails', mock_rails(production: true, logger: nil))

        expect(described_class.logger?).to be false
      end

      it '#production? returns true' do
        stub_const('Rails', mock_rails(production: true))

        expect(described_class.production?).to be true
      end
    end
  end

  context 'when not in Rails' do
    describe '#logger?' do
      it 'always returns false' do
        hide_const('Rails')

        expect(described_class.logger?).to be false
      end
    end

    describe '#production?' do
      it 'always returns false' do
        hide_const('Rails')

        expect(described_class.production?).to be false
      end
    end
  end
end
