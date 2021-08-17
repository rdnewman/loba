# rubocop:disable Layout/IndentationConsistency
# rubocop:disable Layout/IndentationWidth

class HelloWorld
  def initialize
    @x = 42
Loba.ts # see? it's easier to see what to remove later
    @y = 'Charlie'
  end

  def hello
Loba.val :@x
    puts "Hello, #{@y}" if @x == 42
Loba.ts
  end

  def goodbye
Loba.val @y, label: '@y'
    puts "Goodbye, #{@y}" if @x == 42
Loba.ts
  end
end

# rubocop:enable Layout/IndentationWidth
# rubocop:enable Layout/IndentationConsistency
