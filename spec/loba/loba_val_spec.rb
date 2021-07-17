require_relative 'loba_class'

RSpec.describe Loba, '.val' do
  before do
    LobaSpecSupport::OutputControl.suppress!
  end

  after do
    LobaSpecSupport::OutputControl.restore!
  end

  it 'can be called as Loba.val' do
    test_class = Class.new(LobaClass) do
      def hello
        _v = 'hello'
        Loba.val :_v
      end
    end
    expect { test_class.new.hello }.not_to raise_error
  end

  it 'cannot be called as val only' do
    test_class = Class.new(LobaClass) do
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

  it 'can write to STDOUT' do
    test_class = Class.new(LobaClass) do
      def hello
        Loba.ts
      end
    end
    expect { test_class.new.hello }.to output(/\[TIMESTAMP\]/).to_stdout
  end

  describe 'with third argument' do
    it 'as "true", will mark as deprecated' do
      test_class = Class.new(LobaClass) do
        def hello
          v = 'hello'
          Loba.val v, 'value', true
        end
      end
      expected_text = 'DEPRECATION WARNING: use {:production => true} instead to ' \
                      "indicate notice is enabled in production\n"
      expect { test_class.new.hello }.to output(expected_text).to_stderr
    end

    it 'as "false", will mark as deprecated' do
      test_class = Class.new(LobaClass) do
        def hello
          v = 'hello'
          Loba.val v, 'value', false
        end
      end
      expected_text = 'DEPRECATION WARNING: use {:production => false} instead to ' \
                      "indicate notice is disabled in production\n"
      expect { test_class.new.hello }.to output(expected_text).to_stderr
    end

    describe 'as an options hash,' do
      it 'will not mark as deprecated' do
        test_class = Class.new(LobaClass) do
          def hello
            v = 'hello'
            Loba.val v, 'value', {}
          end
        end
        expect { test_class.new.hello }.not_to output.to_stderr
      end

      describe 'and with an object as second value' do
        context 'when supplied via symbol' do
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

          it 'will inspect by default' do
            test_class = Class.new do
              def hello
                @test_val = 5
                Loba.val :self
              end
            end
            expect { test_class.new.hello }.to output(notice_with_instance_variable).to_stdout
          end

          it 'will inspect if option is true' do
            test_class = Class.new do
              def hello
                @test_val = 5
                Loba.val :self, nil, { inspect: true }
              end
            end
            expect { test_class.new.hello }.to output(notice_with_instance_variable).to_stdout
          end

          it 'will not inspect if option is false' do
            test_class = Class.new(LobaClass) do
              def hello
                @test_val = 5
                Loba.val :self, nil, { inspect: false }
              end
            end
            expect do
              test_class.new.hello
            end.to output(notice_without_instance_variable).to_stdout
          end
        end

        context 'when supplied directly' do
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

          it 'will inspect by default' do
            test_class = Class.new do
              def hello
                @test_val = 5
                Loba.val self, 'hello'
              end
            end
            expect { test_class.new.hello }.to output(notice_with_instance_variable).to_stdout
          end

          it 'will inspect if option is true' do
            test_class = Class.new do
              def hello
                @test_val = 5
                Loba.val self, 'hello', { inspect: true }
              end
            end
            expect { test_class.new.hello }.to output(notice_with_instance_variable).to_stdout
          end

          it 'will not inspect if option is false' do
            test_class = Class.new(LobaClass) do
              def hello
                @test_val = 5
                Loba.val self, 'hello', { inspect: false }
              end
            end
            expect do
              test_class.new.hello
            end.to output(notice_without_instance_variable).to_stdout
          end
        end
      end
    end

    it 'given but unrecognized object, treat as deprecated' do
      test_class = Class.new(LobaClass) do
        def hello
          v = 'hello'
          Loba.val v, 'value', []
        end
      end
      expected_text = 'DEPRECATION WARNING: use {:production => false} instead to ' \
                      "indicate notice is disabled in production\n"
      expect { test_class.new.hello }.to output(expected_text).to_stderr
    end
  end
end
