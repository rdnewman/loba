class HelloWorld
  def initialize
    @x = 42
    Loba.ts        # see? it's easier to see what to remove later
    @y = 'Charlie'
  end

  def hello
    Loba.val :@x
    puts "Hello, #{@y}" if @x == 42
    Loba.ts
  end

  def goodbye
    Loba.val @y, '@y'
    puts "Goodbye, #{@y}" if @x == 42
    Loba.ts
  end
end
