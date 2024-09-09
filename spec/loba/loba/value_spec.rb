require_relative '../loba_class'
require 'logger'

RSpec.describe Loba, '.value' do
  before { LobaSpecSupport::OutputControl.suppress! }
  after { LobaSpecSupport::OutputControl.restore! }

  it 'can be called as Loba.val' do
    test_class = Class.new do
      def hello
        _v = 'hello'
        Loba.val :_v
      end
    end
    expect { test_class.new.hello }.not_to raise_error
  end

  it 'cannot be called as val only' do
    test_class = Class.new do
      def hello
        _v = 'hello'
        val :_v
      end
    end
    expect { test_class.new.hello }.to raise_error NameError
  end

  it 'can be called from instance methods' do
    expect { LobaClass.new.base_val }.not_to raise_error
  end

  it 'can be called from class methods' do
    expect { LobaClass.classbase_val }.not_to raise_error
  end

  describe 'when logging' do
    describe 'is not forced' do
      it 'writes to STDOUT' do
        test_class = Class.new do
          def hello
            _v = 'hello'
            Loba.val :_v
          end
        end

        expect { test_class.new.hello }.to output.to_stdout
      end

      it 'and Rails is present, does not write to Rails.logger' do
        stub_const('Rails', mocked_rails_with_logging)

        test_class = Class.new do
          def hello
            _v = 'hello'
            Loba.val :_v
          end
        end
        test_class.new.hello

        expect(Rails.logger).not_to have_received(:debug)
      end
    end

    describe 'is forced' do
      it 'and Rails is present, writes to STDOUT' do
        stub_const('Rails', mocked_rails_with_logging)

        test_class = Class.new do
          def hello
            _v = 'hello'
            Loba.val :_v, log: true
          end
        end

        expect { test_class.new.hello }.to output.to_stdout
      end

      it 'and Rails is not present, writes to STDOUT' do
        hide_const('Rails')

        test_class = Class.new do
          def hello
            _v = 'hello'
            Loba.val :_v, log: true
          end
        end

        expect { test_class.new.hello }.to output.to_stdout
      end

      it 'and Rails is present, writes to Rails.logger' do
        stub_const('Rails', mocked_rails_with_logging)

        test_class = Class.new do
          def hello
            _v = 'hello'
            Loba.val :_v, log: true
          end
        end
        test_class.new.hello

        expect(Rails.logger).to have_received(:debug)
      end
    end

    def mocked_rails_with_logging
      mock_rails(
        production: false,
        logger: mock_rails_logger(present: true, output: StringIO.new)
      )
    end
  end

  unless ENV['LOBA_SPEC_IN_CI']
    describe 'displays the value' do
      let(:nocolor) { /\e\[0m/ }
      let(:nobg)    { /\e\[49m/ } # default background

      let(:methodcolor)   { /\e\[32m/ } # bright green
      let(:stdmethodtext) { /\[\w+#\w+\]\s/ } # [ClassName#method_name], then a space
      let(:stdmethodref)  { /#{methodcolor}#{nobg}#{stdmethodtext}#{nocolor}/ }

      let(:anonclasstext) { /\[<anonymous class>#\w+\]\s/ } # similar to stdmethodtext
      let(:anonclassref)  { /#{methodcolor}#{nobg}#{anonclasstext}#{nocolor}/ }

      let(:varcolor)      { /\e\[92m/ } # dull green
      let(:variablevalue) { /#{varcolor}\w+: #{nocolor}"?.*"?/ } # var_name: value

      let(:codecolor)  { /\e\[90m/ } # dim grey
      let(:codespacer) { /\s*\t/ } # spaces, then tab
      let(:coderef)    { /#{codecolor}#{codespacer}\(in\s.*\)#{nocolor}/ }

      it 'for standard classes' do
        test_object = LobaClass.new

        # essentially the same as:
        #   "\e[32m\e[49m[LobaClass#base_val] \e[0m" \
        #   "\e[92m_bv: \e[0m" \
        #   '"BENJAMIN"' \
        #   "\e[90m    \t" \
        #   '(in /home/richard/src/loba/spec/loba/loba_class.rb:' \
        #   '8' \
        #   ":in `base_val')" \
        #   "\e[0m\n"
        colored_output = /#{stdmethodref}#{variablevalue}#{coderef}\n/

        expect { test_object.base_val }.to output(colored_output).to_stdout
      end

      it 'for anonymous classes' do
        test_class = Class.new do
          def hello
            _v = 'hello'
            Loba.val :_v
          end
        end

        # essentially the same as:
        #   "\e[32m\e49m[\<anonymous class\>#hello] \e[0m" \
        #   "\e[92m_v: \e[0m" \
        #   '"hello"' \
        #   "\e[90m    \t" \
        #   '(in /home/richard/src/loba/spec/loba/loba_val_spec.rb:' \
        #   '108' \
        #   ":in `hello')" \
        #   "\e[0m\n"
        colored_output = /#{anonclassref}#{variablevalue}#{coderef}\n/

        expect { test_class.new.hello }.to output(colored_output).to_stdout
      end
    end
  end

  describe 'with keyword arguments' do
    it 'does not output any error' do
      test_class = Class.new do
        def hello
          v = 'hello'
          Loba.val v, label: 'value'
        end
      end
      expect { test_class.new.hello }.not_to output.to_stderr
    end

    describe 'and first argument' do
      describe 'supplied via symbol' do
        let(:notice_prefix) do
          /
            ^
            .*?
            \[<anonymous class>\#hello\]
            .*?
            self:
            .*?
            \#<\#<Class:0[xX][0-9a-fA-F]{14,16}>:0[xX][0-9a-fA-F]{14,16}
          /x
        end

        let(:notice_without_instance_variable) do
          /#{notice_prefix}?>.*?\(in .*?:\d+:in `hello'\).*?$/
        end

        let(:notice_with_instance_variable) do
          /#{notice_prefix}? @test_val=5>.*?\(in .*?:\d+:in `hello'\).*?$/
        end

        it 'inspects by default' do
          test_class = Class.new do
            def hello
              @test_val = 5
              Loba.val :self
            end
          end
          expect { test_class.new.hello }.to output(notice_with_instance_variable).to_stdout
        end

        it 'inspects if option is true' do
          test_class = Class.new do
            def hello
              @test_val = 5
              Loba.val :self, inspect: true
            end
          end
          expect { test_class.new.hello }.to output(notice_with_instance_variable).to_stdout
        end

        it 'does not inspect if option is false' do
          test_class = Class.new do
            def hello
              @test_val = 5
              Loba.val :self, inspect: false
            end
          end
          expect do
            test_class.new.hello
          end.to output(notice_without_instance_variable).to_stdout
        end
      end

      describe 'supplied directly as an object' do
        let(:notice_prefix) do
          /
            ^
            .*?
            \[<anonymous class>\#hello\]
            .*?
            hello:
            .*?
            \#<\#<Class:0[xX][0-9a-fA-F]{14,16}>:0[xX][0-9a-fA-F]{14,16}
          /x
        end

        let(:notice_with_instance_variable) do
          /#{notice_prefix}? @test_val=5>.*?\(in .*?:\d+:in `hello'\).*?$/
        end

        let(:notice_without_instance_variable) do
          /#{notice_prefix}?>.*?\(in .*?:\d+:in `hello'\).*?$/
        end

        it 'inspects by default' do
          test_class = Class.new do
            def hello
              @test_val = 5
              Loba.val self, label: 'hello'
            end
          end
          expect { test_class.new.hello }.to output(notice_with_instance_variable).to_stdout
        end

        it 'inspects if option is true' do
          test_class = Class.new do
            def hello
              @test_val = 5
              Loba.val self, label: 'hello', inspect: true
            end
          end
          expect { test_class.new.hello }.to output(notice_with_instance_variable).to_stdout
        end

        it 'does not inspect if option is false' do
          test_class = Class.new do
            def hello
              @test_val = 5
              Loba.val self, label: 'hello', inspect: false
            end
          end
          expect do
            test_class.new.hello
          end.to output(notice_without_instance_variable).to_stdout
        end
      end
    end
  end
end
