RSpec.describe 'Loba::Internal' do
  subject(:internal) { Loba::Internal }

  describe '#filter_options' do
    let(:filtered_options) { internal.filter_options(options, allowed_keys) }

    let(:options) do
      {
        first_key: 5,
        second_key: 'something',
        third_key: nil,
        fourth_key: true
      }
    end

    it 'returns a Hash' do
      expect(internal.filter_options(options)).to be_a Hash
    end

    it 'is empty if allowed_keys not provided' do
      expect(internal.filter_options(options)).to be_empty
    end

    it 'is empty if allowed_keys is empty' do
      allowed_keys = []

      expect(internal.filter_options(options, allowed_keys)).to be_empty
    end

    it 'returns Hash of only allowed_keys if options are not valid' do
      expected_result = { an_allowed_key: false }

      result = internal.filter_options(
        'A string is not valid for options',
        [:an_allowed_key]
      )

      expect(result).to eq expected_result
    end

    describe 'when supplied options do not include allowed_keys' do
      let(:allowed_keys) { [:missing_key] }

      it 'includes the missing keys' do
        expect(filtered_options.keys).to include(*allowed_keys)
      end

      it 'has no other keys than allowed_keys' do
        expect(filtered_options.keys - allowed_keys).to be_empty
      end

      it 'missing keys have a value of false' do
        expect(filtered_options[:missing_key]).to be false
      end
    end

    describe 'when supplied options include allowed_keys' do
      let(:random_keys)  { options.keys.sample(rand(1..(options.keys.length - 1))) }
      let(:allowed_keys) { random_keys + [:missing_key] }

      it 'includes all and only allowed keys' do
        expect(filtered_options.keys).to match_array(allowed_keys)
      end

      it 'all values are true or false' do
        # because of :missing_key, they cannot all be true
        expect(filtered_options.values.uniq).to match_array([true, false]).or match_array([false])
      end

      it 'when an option is nil, it is treated as false' do
        result = internal.filter_options(
          { missing_value: nil },
          [:missing_value]
        )

        expect(result[:missing_value]).to be false
      end
    end
  end
end
