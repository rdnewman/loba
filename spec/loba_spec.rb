require 'spec_helper'
require 'loba_class'
require 'hello_world'

describe Loba do
  it 'has a version number' do
    expect(Loba::VERSION).not_to be nil
  end

  context '[output suppressed]' do

    before :all do
      @original_stderr = $stderr
      @original_stdout = $stdout
      $stderr = File.open(File::NULL, "w")
      $stdout = File.open(File::NULL, "w")
    end

    after :all do
      $stderr = @original_stderr
      $stdout = @original_stdout
    end

    describe 'ts (timestamp notice)' do

      it 'can be called as Loba.ts' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba.ts
          end
        end
        expect{test_class.new.hello}.not_to raise_error
      end

      it 'can be called as Loba::ts' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba::ts
          end
        end
        expect{test_class.new.hello}.not_to raise_error
      end

      it 'cannot be called as ts only' do
        test_class = Class.new(LobaClass) do
          def hello
            ts
          end
        end
        expect{test_class.new.hello}.to raise_error NameError
      end

      it 'can be called from instance methods' do
        expect{LobaClass.new.base_ts}.not_to raise_error
      end

      it 'can be called from class methods' do
        expect{LobaClass.classbase_ts}.not_to raise_error
      end

      it 'can write to STDOUT' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba.ts
          end
        end
        expect{test_class.new.hello}.to output(/\[TIMESTAMP\]/).to_stdout
      end

      it 'will mark true argument as deprecated' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba.ts(true)
          end
        end
        expected_text = "DEPRECATION WARNING: use {:production => true} instead to indicate notice is enabled in production\n"
        expect{test_class.new.hello}.to output(expected_text).to_stderr
      end

      it 'will mark false argument as deprecated' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba.ts(false)
          end
        end
        expected_text = "DEPRECATION WARNING: use {:production => false} instead to indicate notice is disabled in production\n"
        expect{test_class.new.hello}.to output(expected_text).to_stderr
      end

      it 'will not mark options argument as deprecated when given as a hash' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba.ts({})
          end
        end
        expect{test_class.new.hello}.not_to output.to_stderr
      end

      it 'will mark unrecognized argument as deprecated' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba.ts []
          end
        end
        expected_text = "DEPRECATION WARNING: use {:production => true} instead to indicate notice is enabled in production\n"
        expect{test_class.new.hello}.to output(expected_text).to_stderr
      end
    end

    describe 'val (value notice)' do

      it 'can be called as Loba.val' do
        test_class = Class.new(LobaClass) do
          def hello
            _v = "hello"
            Loba.val :_v
          end
        end
        expect{test_class.new.hello}.not_to raise_error
      end

      it 'can be called as Loba::val' do
        test_class = Class.new(LobaClass) do
          def hello
            _v = "hello"
            Loba::val :_v
          end
        end
        expect{test_class.new.hello}.not_to raise_error
      end

      it 'cannot be called as val only' do
        test_class = Class.new(LobaClass) do
          def hello
            _v = "hello"
            val :_v
          end
        end
        expect{test_class.new.hello}.to raise_error NameError
      end

      it 'can be called from instance methods' do
        expect{LobaClass.new.base_val}.not_to raise_error
      end

      it 'can be called from class methods' do
        expect{LobaClass.classbase_val}.not_to raise_error
      end

      it 'can write to STDOUT' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba.ts
          end
        end
        expect{test_class.new.hello}.to output(/\[TIMESTAMP\]/).to_stdout
      end

      describe 'with third argument' do
        it 'as "true", will mark as deprecated' do
          test_class = Class.new(LobaClass) do
            def hello
              _v = "hello"
              Loba.val _v, 'value', true
            end
          end
          expected_text = "DEPRECATION WARNING: use {:production => true} instead to indicate notice is enabled in production\n"
          expect{test_class.new.hello}.to output(expected_text).to_stderr
        end

        it 'as "false", will mark as deprecated' do
          test_class = Class.new(LobaClass) do
            def hello
              _v = "hello"
              Loba.val _v, 'value', false
            end
          end
          expected_text = "DEPRECATION WARNING: use {:production => false} instead to indicate notice is disabled in production\n"
          expect{test_class.new.hello}.to output(expected_text).to_stderr
        end

        it 'as an options hash, will not mark as deprecated' do
          test_class = Class.new(LobaClass) do
            def hello
              _v = "hello"
              Loba.val _v, 'value', {}
            end
          end
          expect{test_class.new.hello}.not_to output.to_stderr
        end

        it 'given but unrecognized object, treat as deprecated' do
          test_class = Class.new(LobaClass) do
            def hello
              _v = "hello"
              Loba.val _v, 'value', []
            end
          end
          expected_text = "DEPRECATION WARNING: use {:production => true} instead to indicate notice is enabled in production\n"
          expect{test_class.new.hello}.to output(expected_text).to_stderr
        end
      end

    end

    describe 'Platform module methods' do
      it 'cannot be called directly as part of Loba' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba.rails?
          end
        end
        expect{test_class.new.hello}.to raise_error NameError
      end

      it 'can be called if fully namespaced' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba::Internal::Platform.rails?
          end
        end
        expect{test_class.new.hello}.not_to raise_error
      end
    end

  end

  context '[output allowed]' do
    context 'in HelloWorld demo, using hello method,' do
      subject(:hello_world) { HelloWorld.new.hello }
      it 'writes a first timestamp' do
        expected_output = /\[TIMESTAMP\].*#=.*, diff=.*, at=.*in=.*.rb:4:in `initialize'/
        expect{subject}.to output(expected_output).to_stdout
      end

      it 'writes a value notice' do
        expected_output = /\[HelloWorld#hello\].*@x:.*42.*\(in .*.rb:9:in `hello'/
        expect{subject}.to output(expected_output).to_stdout
      end

      it 'writes a second timestamp' do
        expected_output = /\[TIMESTAMP\].*#=.*, diff=.*, at=.*in=.*.rb:11:in `hello'/
        expect{subject}.to output(expected_output).to_stdout
      end
    end

    context 'in HelloWorld demo, using goodbye method,' do
      subject(:hello_world) { HelloWorld.new.goodbye }

      it 'writes a value notice using a label' do
        expected_output = /\[HelloWorld#goodbye\].*@y:.*Charlie.*\(in .*.rb:15:in `goodbye'/
        expect{subject}.to output(expected_output).to_stdout
      end
    end

  end

end
