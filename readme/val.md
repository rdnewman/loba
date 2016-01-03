#### Value notices:  `Loba::val`

Inserts line to Rails.logger.debug (or to STDOUT if Rails.logger not available) showing value with method and class identification

```
Loba::val :var_sym         # the :var_sym argument is the variable or method name given as a symbol (see below)
```

or

```
Loba::val some_identifier  # directly give a variable or method name instead of a symbol (see below)
```

or

```
Loba::val some_identifier "My label:"  # same as direct variable, but allows a custom label
```

Will produce a notice similar to the following:

```
[Target.some_calculation] my_var: 54       (at /home/usracct/src/myapp/app/models/target.rb:55:in `some_calculation')
```

###### Example 1: Using simple Symbol as argument
```ruby
class HelloWorld
  def hello(name)
Loba::val :name       # best to put Loba statement to far left for easy removal when done
    puts "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
#=> [HelloWorld#hello] name: Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
#=> Hello, Charlie!
```

###### Example 2: Using more complex Symbol as argument
```ruby
class HelloWorld
  def hello(name)
    myHash = {somename: name}
# Loba::val :myHash[name]  won't work directly, but...
Loba::val "myHash[name]".to_sym   # will work -- just express the name as a String and cast to a Symbol
    puts "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
#=> [HelloWorld#hello] myHash[name]: Charlie        (at /path/to/file/hello_world.rb:5:in `hello')
#=> Hello, Charlie!
```

###### Example 3: Using a non-Symbol as argument without a label
```ruby
class HelloWorld
  def hello(name)
Loba::val name
    puts "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
#=> [HelloWorld#hello] Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
#=> Hello, Charlie!
```

###### Example 4: Using a non-Symbol as argument with a label
```ruby
class HelloWorld
  def hello(name)
Loba::val name, "Name:"
    puts "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
#=> [HelloWorld#hello] Name: Charlie        (at /path/to/file/hello_world.rb:3:in `hello')
#=> Hello, Charlie!
```

##### Notice format:

The resulting notice output format is

```
[ccccc.mmmmm] vvvvv: rrrrr         (at /path/to/code/somecode.rb:ll:in 'some_method')
```

where
* `ccccc` is the name of the class from where `Loba::val` was invoked,
* `mmmmm` is the name of the method from where `Loba::val` was invoked,
* `vvvvv` is generally the name of the variable for which `Loba::val` is inspecting, or any custom label given,
* `rrrrr` is the result of inspecting what `Loba::val` was invoked against,
* `/path/to/code/somecode.rb` is the source code file that invoked `Loba::val`,
* `ll` is the line number of the source code file that invoked `Loba::val`, and
* `some_method`is the method in which `Loba::val` was invoked.


Notes:
* `ccccc`:  Ruby supports anonymous classes (e.g., `= Class.new`).  If an anonymous class, "<anonymous class>" will be output here.
* `mmmmm`:  Ruby supports anonymous methods, procs, and lambdas.  If an anonymous method, et al, "<anonymous method>" will be output here.
* `vvvvv`:  This depends on the argument being provided:  if a symbol, then this field will use that symbol to determine the name and present it here.  If not, nothing will appear for this field.
* `rrrrr`:  The value of the variable given to `Loba::val`.  `inspect` may be used.
