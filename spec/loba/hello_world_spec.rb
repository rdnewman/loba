require_relative 'hello_world'

RSpec.describe HelloWorld do
  let(:hello_world) { described_class.new }

  describe '#hello' do
    it 'writes a first timestamp' do
      expected_output = /\[TIMESTAMP\].*#=.*, diff=.*, at=.*in=.*.rb:7:in `initialize'/
      expect { hello_world.hello }.to output(expected_output).to_stdout
    end

    it 'writes a value notice' do
      expected_output = /\[HelloWorld#hello\].*@x:.*42.*\(in .*.rb:12:in `hello'/
      expect { hello_world.hello }.to output(expected_output).to_stdout
    end

    it 'writes a second timestamp' do
      expected_output = /\[TIMESTAMP\].*#=.*, diff=.*, at=.*in=.*.rb:14:in `hello'/
      expect { hello_world.hello }.to output(expected_output).to_stdout
    end
  end

  describe '#goodbye' do
    it 'writes a value notice using a label' do
      expected_output = /\[HelloWorld#goodbye\].*@y:.*Charlie.*\(in .*.rb:18:in `goodbye'/
      expect { hello_world.goodbye }.to output(expected_output).to_stdout
    end
  end
end
