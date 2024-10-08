#### Value notices:  `Loba.val`

Writes line to `$stdout` (or optionally to Rails.logger.debug if available) showing value with method and class identification.

```ruby
Loba.val :var_sym         # the :var_sym argument is the variable or method name given as a symbol (see below)
```

or

```ruby
Loba.val some_identifier  # directly give a variable or method name instead of a symbol (see below)
```

or

```ruby
Loba.val some_identifier, label: "My label:"  # same as direct variable, but allows a custom label
```

Will produce a notice similar to the following:

```text
[Target.some_calculation] my_var: 54       (in /home/usracct/src/myapp/app/models/target.rb:55:in `some_calculation')
```

`Loba.value` is an alias for `Loba.val`.

###### Example 1: Using simple Symbol as argument

```ruby
class HelloWorld
  def hello(name)
Loba.val :name       # put Loba statement to far left to remind you to remove when done
    puts "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
#=> [HelloWorld#hello] name: Charlie        (in /path/to/file/hello_world.rb:3:in `hello')
#=> Hello, Charlie!
```

###### Example 2: Using more complex Symbol as argument

```ruby
class HelloWorld
  def hello(name)
    myHash = {somename: name}
# Loba.val :myHash[name]  won't work directly, but...
Loba.val "myHash[name]".to_sym   # will work -- just express the name as a String and cast to a Symbol
    puts "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
#=> [HelloWorld#hello] myHash[name]: Charlie        (in /path/to/file/hello_world.rb:5:in `hello')
#=> Hello, Charlie!
```

###### Example 3: Using a non-Symbol as argument without a label

```ruby
class HelloWorld
  def hello(name)
Loba.val name
    puts "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
#=> [HelloWorld#hello] Charlie        (in /path/to/file/hello_world.rb:3:in `hello')
#=> Hello, Charlie!
```

###### Example 4: Using a non-Symbol as argument with a label

```ruby
class HelloWorld
  def hello(name)
Loba.val name, label: "Name:"
    puts "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
#=> [HelloWorld#hello] Name: Charlie        (in /path/to/file/hello_world.rb:3:in `hello')
#=> Hello, Charlie!
```

##### Notice format

The resulting notice output format is

```text
[ccccc.mmmmm] vvvvv: rrrrr         (in /path/to/code/somecode.rb:LL:in 'some_method')
```

where

* `ccccc` is the name of the class from where `Loba.val` was invoked,
* `mmmmm` is the name of the method from where `Loba.val` was invoked,
* `vvvvv` is generally the name of the variable for which `Loba.val` is inspecting, or any custom label given,
* `rrrrr` is the result of inspecting what `Loba.val` was invoked against,
* `/path/to/code/somecode.rb` is the source code file that invoked `Loba.val`,
* `LL` is the line number of the source code file that invoked `Loba.val`, and
* `some_method`is the method in which `Loba.val` was invoked.

Notes:

* `ccccc`:  Ruby supports anonymous classes (e.g., `= Class.new`).  If an anonymous class, "<anonymous class>" will be output here.
* `mmmmm`:  Ruby supports anonymous methods, procs, and lambdas.  If an anonymous method, et al, "<anonymous method>" will be output here.
* `vvvvv`:  This depends on the argument being provided:  if a symbol, then this field will use that symbol to determine the name and present it here.  If not, nothing will appear for this field (and so the `label` option will be useful).
* `rrrrr`:  The value of the variable given to `Loba.val`. `inspect` may be used to control its behavior (see [options](#options) below).

##### Options

The following options may be provided via keywords:

* `label`: give a string to explicitly provide a label to use in the notice (see sample above) \[_default: attempts to infer a label from the first argument]_\]
* `inspect`: true if this value notice is to use #inspect against the content being evaluated; occasionally, `inspect: false` can give a more useful result \[_default: `true`_\]
* `production`: true if this value notice is to be enabled when running in :production environment (see ["Environment Notes"](README.md#environment-notes)) \[_default: `false`_\]
* `log`: true if output is to be sent to a log [_default: `false`_\]
* `logger`: accepts a (non-default) `Logger` to write to (also assumes `log` to be true, unless explicitly set to `false`) \[_default: nil_\]
* `logdev`: for non-Rails environments -- accepts a `logdev` for Loba's fallback Logger to write to; ignored when `logger` is specified or when in Rails [_default: nil_\]
* `out`: true if this value notice is `puts` to `$stdout` [_default: `true`_\]

###### Example 5: Using special options

```ruby
Loba.val name, label: "Name:", inspect: false
```

```ruby
Loba.val :name, production: true
```

```ruby
Loba.val :name, label: "Name:", log: true
```
