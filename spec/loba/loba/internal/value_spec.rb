RSpec.describe Loba::Internal::Value do
  let(:subject_value_variable_name) { 'subject_value' }
  let!(:argument)                   { subject_value_variable_name.to_sym }

  let(:random_integer) { rand(-1000..1000) }
  let(:random_string)  { rand(36**rand(10)).to_s(36) } # usually 10 chars long (may be shorter)
  let!(:subject_value) { [random_integer, random_string].sample }

  # these are hoped to be reasonably stable across rspec versions and refer to where
  # RSpec is actually executing the RSpec helper :value_used_in_mocked_class.  To avoid
  # these would require repeating the content of :value_used_in_mocked_class within
  # each test.
  # TODO: any way to make these more stable but still sufficiently precise for validation?
  let(:rspec_invokation_tag) do
    # '[RSpec::Core::MemoizedHelpers::ThreadsafeMemoized#fetch_or_store]'
    '[R]'
  end

  let(:rspec_invoked_code_file) do
    /\/(?:.*)\/rspec\/core\/memoized_helpers.rb:\d+:in\s/
  end
  let(:direct_rspec_invokation_line) do
    /
      #{rspec_invoked_code_file}
      `fetch'
    /x
  end
  let(:mocked_rspec_invokation_line) do
    /
      #{rspec_invoked_code_file}
      `block\s\(\d+\slevels\)\sin\sfetch_or_store'
    /x
  end

  shared_examples 'phrases_used_in_mocked_class' do |initial_character, inspection = true|
    # These let statements support the randomization used in MockValuationClasses.
    # That randomization is akin to, say, the Faker gem so that various permutations arise
    let(:value_used_in_mocked_class) do
      # since Valuation, by default, uses .inspect, need to account for either possibility
      if inspection
        Loba::Internal.unquote(object.class.content.inspect.to_s)
      else
        object.class.content.to_s
      end
    end
    let(:label_supplied_by_mocked_class) { object.class.label }

    # The remainder of these examples are pretty vanilla RSpec. However, the default
    # label, when inferred, will depend on whether the variable is local (prefixed
    # in MockValuationClasses with an underscore) or instance (prefixed with "@").

    describe 'when calling with a symbol' do
      context 'without supplying a label,' do
        let(:phrases) { object.symbol_without_label }

        it 'returns hash with expected keys' do
          expect(phrases.keys).to contain_exactly(:label, :line, :tag, :value)
        end

        it 'infers a default label' do
          expect(phrases[:label]).to match(/#{initial_character}v:/)
        end

        it 'retrieves value' do
          expect(phrases[:value]).to eq value_used_in_mocked_class
        end

        it 'retrieves code line where invoked' do
          expected_line = /spec\/support\/mock_value_classes.rb:\d{2,3}:in `symbol_without_label'$/
          expect(phrases[:line]).to match expected_line
          # expect(phrases[:line]).to match mocked_rspec_invokation_line
        end

        it 'retrieves method where invoked' do
          expect(phrases[:tag]).to eq "[#{object.class.name}#symbol_without_label]"
        end
      end

      context 'when supplying a label' do
        let(:phrases) { object.symbol_with_label }

        it 'returns hash with expected keys' do
          expect(phrases.keys).to contain_exactly(:label, :line, :tag, :value)
        end

        it 'uses supplied label' do
          expect(phrases[:label]).to eq "#{label_supplied_by_mocked_class}:"
        end

        it 'retrieves value' do
          expect(phrases[:value]).to eq value_used_in_mocked_class
        end

        it 'retrieves code line where invoked' do
          expected_line = /spec\/support\/mock_value_classes.rb:\d{2,3}:in `symbol_with_label'$/
          expect(phrases[:line]).to match expected_line
        end

        it 'retrieves method where invoked' do
          expect(phrases[:tag]).to eq "[#{object.class.name}#symbol_with_label]"
        end
      end
    end

    describe 'when calling directly' do
      context 'without supplying a label,' do
        let(:phrases) { object.direct_without_label }

        it 'returns hash with expected keys' do
          expect(phrases.keys).to contain_exactly(:label, :line, :tag, :value)
        end

        it 'cannot infer a default label' do
          expect(phrases[:label]).to eq '[unknown value]:'
        end

        it 'retrieves value' do
          expect(phrases[:value]).to eq value_used_in_mocked_class
        end

        it 'retrieves code line where invoked' do
          expected_line = /spec\/support\/mock_value_classes.rb:\d{2,3}:in `direct_without_label'$/
          expect(phrases[:line]).to match expected_line
        end

        it 'retrieves method where invoked' do
          expect(phrases[:tag]).to eq "[#{object.class.name}#direct_without_label]"
        end
      end

      context 'when supplying a label' do
        let(:phrases) { object.direct_with_label }

        it 'returns hash with expected keys' do
          expect(phrases.keys).to contain_exactly(:label, :line, :tag, :value)
        end

        it 'uses supplied label' do
          expect(phrases[:label]).to eq "#{label_supplied_by_mocked_class}:"
        end

        it 'retrieves value' do
          expect(phrases[:value]).to eq value_used_in_mocked_class
        end

        it 'retrieves code line where invoked' do
          expected_line = /spec\/support\/mock_value_classes.rb:\d{2,3}:in `direct_with_label'$/
          expect(phrases[:line]).to match expected_line
        end

        it 'retrieves method where invoked' do
          expect(phrases[:tag]).to eq "[#{object.class.name}#direct_with_label]"
        end
      end
    end
  end

  describe '.phrases' do
    context 'when calling directly from rspec' do
      let(:phrases) { described_class.phrases(argument: argument) }
      let!(:lineno) { __LINE__ } # must immediately follow `let(:phrases)`

      it 'returns hash with expected keys' do
        expect(phrases.keys).to contain_exactly(:label, :line, :tag, :value)
      end

      it 'infers a default label when no label supplied' do
        expect(phrases[:label]).to eq "#{subject_value_variable_name}:"
      end

      it 'retrieves value' do
        expect(phrases[:value]).to eq subject_value.to_s
      end

      it 'retrieves code line where invoked' do
        # will be in this rspec source code file where `let(:phrases)` is defined
        expected_line = /#{__FILE__}:#{lineno - 1}:in `block \(\d levels\) in/

        expect(phrases[:line]).to match expected_line
      end

      it 'retrieves method where invoked' do
        # because direct, we have to infer what RSpec will do; this can be
        # calculated from example.metadata, but that's more involved and less readable
        example_group_hierarchy = 'Phrases::WhenCallingDirectlyFromRspec'
        expected_tag_content = 'RSpec::ExampleGroups::' \
                               "#{described_class.name.tr('::', '')}::" \
                               "#{example_group_hierarchy}" \
                               '#phrases' # `let(:phrases)` is where its invoked

        expected_tag = "[#{expected_tag_content}]"
        expect(phrases[:tag]).to eq expected_tag
      end

      it 'label indicates when a supplied label is not usable' do
        phrases_from_bad_label = described_class.phrases(argument: argument, label: {})

        expect(phrases_from_bad_label[:label]).to eq '[unknown value]:'
      end
    end

    describe 'and inspecting (default)' do
      context 'with object using local variables' do
        let(:object) { LobaSpecSupport::MockValueClasses::LocalVariable.new }

        it_behaves_like 'phrases_used_in_mocked_class', '_'
      end

      context 'with object using instance variables' do
        let(:object) { LobaSpecSupport::MockValueClasses::InstanceVariable.new }

        it_behaves_like 'phrases_used_in_mocked_class', '@'
      end
    end

    describe 'and not inspecting' do
      context 'with object using local variables' do
        let(:object) { LobaSpecSupport::MockValueClasses::LocalVariableWithoutInspect.new }

        it_behaves_like 'phrases_used_in_mocked_class', '_', false
      end

      context 'with object using instance variables' do
        let(:object) { LobaSpecSupport::MockValueClasses::InstanceVariableWithoutInspect.new }

        it_behaves_like 'phrases_used_in_mocked_class', '@', false
      end
    end
  end
end
