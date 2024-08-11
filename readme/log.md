#### Output

Generally Loba always writes to $stdout regardless of what logging behavior may be specified.

This can be overridden with the `out:` option which can take any IO stream or `nil`. This option behaves the same whether in Rails or non-Rails environments.

Since Loba uses `puts` internally, this content will be newline (`$\`) separated (usually `\n`).

##### No output

```ruby
..., out: nil # no output, no logging; basically disables the Loba command
```

##### IO stream

```ruby
..., out: $stdout # same as default Loba
```

```ruby
..., out: $stderr # writes to $stderr instead of $stdout.
```

```ruby
text = StringIO.new
..., out: text # writes to a string
text.close
puts text.string # displays content from Loba
```

```ruby
file = File.new(`somefile.txt`)
..., out: file # writes to somefile.txt
file.close
```

#### Logging

Default logging behavior can differ depending on the environment but can be overridden.

$stdout generally will always be written to, but this can be overridden.

When logging, :debug level is always used (e.g., `logger.debug`) and cannot be overridden.

##### `log`

`log: true` will cause logging to occur.

##### `logger`

`logger: some_log` will cause logging to occur and will specify a logger to write to instead of following default logging behavior.

##### `logdev`

In non-Rails environments, `logdev: somefile.log` will cause the logger to write to the given target. Behaves exactly as Ruby `Logger.new(somefile.log, ...)` given that it merely passes the value given here to `Logger.new`.

In Rails environment, this value is ignored and logging behavior can only be overridden by `logger` option.

This option is ignored when `log` is not specified or is set to `false`.

This option is also ignored when `logger` is specified (since that already defines a target).

##### Default behavior

For default logging behavior, specify `log: true`, without specifying `logger` or `logdev`:

```ruby
..., log: true
```

In a Rails environment, Loba will by default write to `Rails.logger.debug`. Rails's logger formatter is used.

In a non-Rails environment, Loba will write to a new Logger at the :debug level. In this case, Loba's default formatter does not write any content beyond the message content that show up typically to $stdout (i.e., no default surrounding content).

##### Custom logger

For custom logging behavior, specify `logger`. It will write to the given logger at a :debug level (i.e., `some_log.debug`).

```ruby
some_log = Logger.new
..., log: true, logger: some_log
```

Note that the formatter of the specified logger is used. This may (generally will) cause additional content around Loba's messages.

When `log` is not specified, setting `logger` will cause `log: true` to be assumed:

```ruby
some_log = Logger.new
..., logger: some_log
```

##### Custom logging device

In non-Rails environment, logging behavior can also be customized by specifying a specific target using Loba's default logger.

```ruby
..., log: true, logdev: somefile.log
```

In the above case, `somefile.log` will be written to using Loba's formatter at the :debug level. Loba's formatter does not write any content beyond the messages that show up typically to $stdout (i.e., no surrounding content).

If `log: true` is not specified, `logdev` will be ignored.

In a Rails environment, `logdev` is always ignored.

##### Forcing no logging with `logger`

This seems unnecessary, but `log: false` will force `logger` to be ignored and no logging will occur. Note that, likewise, merely not specifying either `log` or `logger` also results in no logging occurring.

For overriding:
```ruby
some_log = Logger.new
Loba.ts, log: false, logger: some_log # no logging occurs, `logger` ignored
```

or just
```ruby
some_log = Logger.new
Loba.ts # no logging occurs
```

In non-Rails environments, another way that logging can be turned of is by specifying `nil` to `logdev`:

```ruby
..., log: true, logdev: nil
```

This is because Ruby's Logger supports `nil` as a target and causes no logging to occur.
