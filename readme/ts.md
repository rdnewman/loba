#### Timestamp notices:  `Loba.ts`

Outputs a timestamped notice, useful for quick traces to see the code path and easier than, say, [Kernel#set_trace_func](http://ruby-doc.org/core-2.2.3/Kernel.html#method-i-set_trace_func).
Also does a simple elapsed time check since the previous timestamp notice to help with quick, minimalist profiling.

For example,

```text
[TIMESTAMP] #=0002, diff=93.478016, at=1451444972.970602    (in=/home/usracct/src/myapp/app/models/target.rb:55:in `some_calculation')
```

To invoke,

```ruby
Loba.ts    # no arguments
```

`Loba.timestamp` is an alias for `Loba.ts`.

The resulting notice output format is

```text
[TIMESTAMP] #=nnnn, diff=ss.ssssss, at=tttttttttt.tttttt    (in=/path/to/code/somecode.rb:LL:in 'some_method')
```

where

* `nnn` ("#=") is a sequential numbering (1, 2, 3, ...) of timestamp notices,
* `ss.ssssss` ("diff=") is number of seconds since the last timestamp notice was output (i.e., relative time),
* `tttttttttt.tttttt` ("at=") is Time.now (as seconds) (i.e., absolute time),
* `/path/to/code/somecode.rb` ("in=") is the source code file that invoked `Loba.ts`,
* `LL` ("in=...:") is the line number of the source code file that invoked `Loba.ts`, and
* `some_method` is the method in which `Loba.ts` was invoked.

##### Options

The following keyword argument may be specified when calling:

* `production`: true if this timestamp notice is to be enabled when running in :production environment (see ["Environment Notes"](README.md#environment-notes)) \[_default: `false`_\]
* `log`: `true` true if output is to be sent to both $stdout and to a log [_default: `false`_\]
* `logger`: accepts a (non-default) logger to write to (also assumes `log` to be true, unless explicitly set to `false`) \[_default: nil_\]

###### Examples using options

```ruby
Loba.ts production: true
```

```ruby
Loba.ts(production: true)
```

```ruby
Loba.ts log: true # if Rails uses Rails.logger by default; if not in Rails
```

```ruby
Loba.ts(log: true)
```

```ruby
logger = Logger.new
Loba.ts log: true, logger: logger # logs to logger instead of default log
```

```ruby
logger = Logger.new
Loba.ts(logger: logger) # same as log: true, logger: logger
```

```ruby
logger = Logger.new
Loba.ts(log: false, logger: logger) # no logging, ignores logger
```

```ruby
Loba.ts(production: true, log: true)
```
