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
      it 'can be called if namespaced' do
        test_class = Class.new(LobaClass) do
          def hello
            Loba::Platform.rails?
          end
        end
        expect{test_class.new.hello}.not_to raise_error
      end
    end

  end

  context '[output allowed]' do
    context 'in HelloWorld demo,' do
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
  end

end
