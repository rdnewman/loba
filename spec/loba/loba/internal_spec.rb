RSpec.describe Loba::Internal do
  describe '.strip_quotes' do
    describe 'strips quotes from' do
      it 'simple quoted strings' do
        input = '"some string"'.freeze
        expected_output = 'some string'.freeze
        expect(described_class.strip_quotes(input)).to eq expected_output
      end

      it 'quoted strings that have a new line embedded' do
        input = '"some\nstring"'.freeze
        expected_output = 'some\nstring'.freeze
        expect(described_class.strip_quotes(input)).to eq expected_output
      end
    end

    describe 'does not change' do
      it 'unquoted strings' do
        input = 'some string'.freeze
        expected_output = input.freeze
        expect(described_class.strip_quotes(input)).to eq expected_output
      end

      it 'strings with only a leading quote' do
        input = '"some string'.freeze
        expected_output = input.freeze
        expect(described_class.strip_quotes(input)).to eq expected_output
      end

      it 'strings with only a trailing quote' do
        input = 'some string"'.freeze
        expected_output = input.freeze
        expect(described_class.strip_quotes(input)).to eq expected_output
      end

      it 'quoted strings ending in a new line' do
        input = '"some string"\n'.freeze
        expected_output = input.freeze
        expect(described_class.strip_quotes(input)).to eq expected_output
      end

      it 'numbers' do
        input = 5
        expected_output = input
        expect(described_class.strip_quotes(input)).to eq expected_output
      end

      it 'internal values in hashes' do
        input = { somekey: '"some string"' }
        expected_output = input
        expect(described_class.strip_quotes(input)).to eq expected_output
      end
    end
  end
end
