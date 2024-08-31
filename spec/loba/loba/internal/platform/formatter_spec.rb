RSpec.describe Loba::Internal::Platform::Formatter do
  describe '#call when msg param' do
    it 'is a String, returns that string with only a new line added' do
      formatter = described_class.new
      message = 'test'
      expect(formatter.call(nil, nil, nil, message)).to eq "#{message}\n"
    end

    describe 'is an Exception' do
      subject(:formatter) { described_class.new }

      it 'with an empty backtrace' do
        error_text = 'test@message'
        raised_error = StandardError.new(error_text)

        expected_entry = "#{error_text} (#{raised_error.class})"
        expect(formatter.call(nil, nil, nil, raised_error)).to eq "#{expected_entry}\n"
      end

      it 'with a backtrace' do
        error_text = 'test@message'
        backtrace = caller
        raised_error = StandardError.new(error_text)
        raised_error.set_backtrace(backtrace)

        expected_entry = "#{error_text} (#{raised_error.class})\n#{backtrace}"
        expect(formatter.call(nil, nil, nil, raised_error)).to eq "#{expected_entry}\n"
      end
    end

    it 'is an Integer' do
      formatter = described_class.new
      expect(formatter.call(nil, nil, nil, 55)).to eq "55\n"
    end
  end
end
