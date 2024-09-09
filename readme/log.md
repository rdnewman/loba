> The behavior described in this document assumes that Loba is not being run in a Rails production environment. By default, Loba is disabled in Rails production environments (see ["Environment Notes"](README.md#environment-notes)).

`$stdout` generally will always be written to, but this behavior can be overridden.

Logging generally will not occur, but this behavior can be overridden.

Loba tries to make intelligent choices about output occurs based on chosen options while still offering full control.

#### Logging

To ensure logging, set `:log` to `true`. When logging, behavior can differ depending on the environment but this can be overridden.

`$stdout` generally will always be written to, but this can be overridden.

When logging, `:debug` level is always used (e.g., `logger.debug`). This cannot be overridden.

If `:out` is set to false, then `:log` will be defaulted to `true`. If explicitly specified, `log: false` will still prevent logging.

> NOTE: to reduce the chance of doubled output, when not in Rails, `out` will always be treated as `false` when `log` is true and `logdev` is set to `$stdout`. If output is still seen to be doubled to `$stdout` (which
can occur in other ways), explicitly set `out: false`.

##### `log`

`log: true` will cause logging to occur.

##### `logger`

`logger: some_log` will cause logging to occur (i.e., assumes `log: true`) and specifies a specific Logger to write to instead of following default logging behavior.

##### `logdev`

In non-Rails environments, `logdev: "somefile.log"` will cause the logger to write to the given target (e.g., "somefile.log"). Behaves exactly as Ruby `Logger.new("somefile.log", ...)` given that it merely passes the value given here to `Logger.new`.

Under the following cases, `logdev` will be ignored:
* when `log` is not specified or is set to `false`
* when `logger` is specified (because that defines its own `logdev` target)
* when in Rails environments -- logging behavior can then only be overridden by the `logger` option

##### Default behavior

For default logging behavior, specify `log: true`, without specifying `logger` or `logdev`:

```ruby
..., log: true
```

In a Rails environment, Loba will by default write to `Rails.logger.debug`. Rails's logger formatter is used.

In a non-Rails environment, Loba will write to a new Ruby Logger at the :debug level. In this case, Loba's default formatter does not write any content beyond the message content that show up typically to `$stdout` (i.e., there is no default surrounding content).

##### Custom logger

For custom logging behavior, specify `logger`. It will write to the given logger at a :debug level (i.e., `some_log.debug`).

The formatter of the specified logger is used. This may (generally will) cause additional content around Loba's messages.

```ruby
some_log = Logger.new
..., log: true, logger: some_log
```

When `log` is not specified, setting `logger` will cause `log: true` to be assumed:

```ruby
some_log = Logger.new
..., logger: some_log # log: true now assumed
```

##### Custom logging device

In non-Rails environments, logging behavior can also be customized by specifying a specific target for Loba's default logger (default: `$stdout`).

```ruby
..., log: true, logdev: "somefile.log"
```

In the above case, `somefile.log` will be written to using Loba's formatter at the :debug level. Loba's formatter does not write any content beyond the messages that show up typically to `$stdout` (i.e., no surrounding content).

If `log: true` is not specified, `logdev` will be ignored.

In a Rails environment, `logdev` is always ignored.

##### Forcing no logging with `logger`

This seems unnecessary, but `log: false` will force `logger` and `logdev` to be ignored and no logging will occur. Again, merely not specifying either `log` or `logger` is enough to have no logging occur (in most cases).

For overriding:
```ruby
some_log = Logger.new
Loba.ts, log: false, logger: some_log # no logging occurs, `logger` ignored
```

or just
```ruby
some_log = Logger.new
Loba.ts # no logging occurs (by default, no logging occurs)
```

In non-Rails environments, another way that logging can be "turned off" is by specifying `nil` or `File::NULL` to `logdev`:

```ruby
..., log: true, logdev: nil
```

This is because Ruby's Logger supports `nil` (or `File::NULL`) as a target and causes no logging content to be written.

#### Controlling output with `out`

Generally Loba always writes to `$stdout` (via `puts`) regardless of what logging behavior may be specified.

This can be overridden with the `out:` option. If set to `false` (or is falsey), no output will be sent to `$stdout`. By default, this will then imply that `log` is true unless that is overridden to `false` as well.

Note in the examples below that there are special cases where `out` is forced to be false.

This option behaves the same whether in Rails or non-Rails environments.

##### Will use `puts` to output to console

```ruby
..., out: true # same as default Loba
```

```ruby
..., out: $stderr # non-falsey value treated as true, continues to write to $stdout (as with any other non-falsey value)
```
##### Will not use `puts` to output to console

```ruby
..., out: false # no output; implies `log: true` by default unless `log` specified (see below)
```

```ruby
..., out: nil # as a falsey value, treated as false
```

```ruby
..., out: File::NULL # special case: explicitly treated as `out: false`
```

```ruby
...log: false, out: false # no output at all; Loba command is essentially disabled
```

```ruby
...log: true, logdev: $stdout, out: true # special case: treated as `out: false` to avoid doubling output to `$stdout`.
```
