RSpec.describe Loba::Internal do
  describe '.unquote' do
    ##################
    # custom matcher
    ##################
    matcher :be_changed_by_unquote do
      match do |actual|
        @original = actual.freeze
        @unquoted = described_class.unquote(actual)

        result   = @unquoted != @original
        result &&= (@unquoted == @target) if target?

        result
      end

      match_when_negated do |actual|
        raise 'do not use .into when negating be_changed_by_unquote' if target?

        described_class.unquote(actual) == actual.freeze
      end

      chain :into do |target|
        @target = target
      end

      description do
        "be changed #{"into \"#{@target}\"" if target?}" # nested interpolation
      end

      def target?
        defined?(@target)
      end
    end

    ##################
    # test specs
    ##################
    describe 'removes quotes from' do
      it 'simple quoted string' do
        content = '"some string"'
        expect(content).to be_changed_by_unquote.into 'some string'
      end

      it 'quoted strings with embedded new line' do
        content = '"some\nstring"'
        expect(content).to be_changed_by_unquote.into 'some\nstring'
      end
    end

    describe 'does not change' do
      it 'unquoted string' do
        content = 'some string'
        expect(content).not_to be_changed_by_unquote
      end

      it 'strings with only a leading quote' do
        content = '"some string'
        expect(content).not_to be_changed_by_unquote
      end

      it 'strings with only a trailing quote' do
        content = 'some string"'
        expect(content).not_to be_changed_by_unquote
      end

      it 'quoted strings ending in a new line' do
        content = '"some string"\n'
        expect(content).not_to be_changed_by_unquote
      end

      it 'quoted strings with leading space' do
        content = ' "some string"'
        expect(content).not_to be_changed_by_unquote
      end

      it 'quoted strings with trailing space' do
        content = '"some string" '
        expect(content).not_to be_changed_by_unquote
      end

      it 'numbers' do
        content = 5
        expect(content).not_to be_changed_by_unquote
      end

      it 'internal values in hashes' do
        content = { somekey: '"some string"' }
        expect(content).not_to be_changed_by_unquote
      end
    end
  end
end
