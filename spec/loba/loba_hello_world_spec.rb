require_relative 'hello_world'

RSpec.describe 'Loba [HelloWorld demo]' do
  describe 'using hello method,' do
    subject(:hello_world) { HelloWorld.new.hello }

    it 'writes a first timestamp' do
      expected_output = /\[TIMESTAMP\].*#=.*, diff=.*, at=.*in=.*.rb:4:in `initialize'/
      expect { hello_world }.to output(expected_output).to_stdout
    end

    it 'writes a value notice' do
      expected_output = /\[HelloWorld#hello\].*@x:.*42.*\(in .*.rb:9:in `hello'/
      expect { hello_world }.to output(expected_output).to_stdout
    end

    it 'writes a second timestamp' do
      expected_output = /\[TIMESTAMP\].*#=.*, diff=.*, at=.*in=.*.rb:11:in `hello'/
      expect { hello_world }.to output(expected_output).to_stdout
    end
  end

  describe 'using goodbye method,' do
    subject(:hello_world) { HelloWorld.new.goodbye }

    it 'writes a value notice using a label' do
      expected_output = /\[HelloWorld#goodbye\].*@y:.*Charlie.*\(in .*.rb:15:in `goodbye'/
      expect { hello_world }.to output(expected_output).to_stdout
    end
  end
end
