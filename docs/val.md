# Value records: `Lba.val`

`Lba.val` records a value, along with the class, method, file, and line it was
called from, as one JSON object per line in the current run's sink.

```ruby
Lba.val :var_sym                     # a Symbol names something in the caller: a local, an instance variable, a method...
Lba.val some_value                   # anything else is recorded as given
Lba.val some_value, label: "Name"    # a label for a value that can't name itself
```

`Lba.value` is an alias for `Lba.val`.

## Examples

Each example shows the fields that matter to it; every record also carries the
fields listed under [The record](#the-record).

### Example 1: a Symbol as the argument

```ruby
class HelloWorld
  def hello(name)
Lba.val :name       # put Lba statements at the far left to help remember to remove them
    "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
```

```json
{"type":"val","file":"hello_world.rb","line":3,"class_name":"HelloWorld","method_name":"hello","method_type":"instance","label":"name","value":"Charlie","value_type":"String","inspected":false,"truncated":false}
```

The label comes from the Symbol. A Symbol can also name an instance variable
(`Lba.val :@total`), a method (`Lba.val :current_user`), `:self`, or a constant.

A Symbol argument is always treated as a name, never as the value to record, so
a variable that holds a Symbol has to be passed by name (`Lba.val :status`), not
directly (`Lba.val status`).

### Example 2: an expression as a Symbol

An expression a bare Symbol can't spell works when written as a String and cast:

```ruby
Lba.val "my_hash[:name]".to_sym
```

It's evaluated in the caller, and the label is the expression itself
(`"label":"my_hash[:name]"`).

### Example 3: a value given directly, without a label

```ruby
Lba.val name
```

```json
{"label":null,"value":"Charlie","value_type":"String"}
```

A value given directly can't name itself, so `label` is `null`.

### Example 4: a value given directly, with a label

```ruby
Lba.val name, label: "Name"
```

```json
{"label":"Name","value":"Charlie","value_type":"String"}
```

## Where records go

Each process run writes to its own file, named for its run id:

- inside Rails: `tmp/lba/runs/<run_id>.jsonl` under `Rails.root`
- otherwise: `.lba/runs/<run_id>.jsonl` under the current directory

The `LBA_SINK` environment variable overrides that path for the whole process,
and the `sink:` option overrides it for one call, with a path or any IO (such as
`$stdout` or a `StringIO`). If the directory can't be created or written to,
records go to `$stdout` instead.

A forked child process, such as a Puma or Unicorn worker, starts its own run and
file.

## The record

| Field | Meaning |
|---|---|
| `schema` | Record format version, currently `1` |
| `run_id` | This process run, e.g. `20260926T210626Z-894825-b10f` |
| `seq` | Order of this record among all records in the run |
| `site_seq` | Order of this record among records from the same call site (file and line) |
| `type` | `"val"` |
| `wall_time` | Seconds since the epoch, when recorded |
| `mono_time` | A monotonic clock reading, unaffected by system clock changes |
| `diff` | Seconds since the previous record from the same call site; `null` for the first |
| `file`, `line` | Where `Lba.val` was called |
| `class_name` | The caller's class, or the class itself inside a class method; `"<anonymous class>"` for an unnamed one |
| `method_name` | The caller's method; `"<anonymous method>"` outside any method |
| `method_type` | `"instance"` or `"class"` |
| `label` | The given or inferred label, or `null` |
| `value` | The value, as JSON (see below) |
| `value_type` | The value's class name |
| `inspected` | `true` if any part of the value had no JSON form and was rendered as text |
| `truncated` | `true` if any part of the value was cut short (see [Limits](#limits)) |
| `error` | Present instead of `value` and its flags when evaluating the Symbol raised (see [Errors](#errors)) |

Strings, numbers, `true`, `false`, `nil`, Arrays, and Hashes are recorded as
JSON, including inside each other; Symbols are recorded as JSON strings, and
Hash keys always become JSON strings. Anything else is rendered as text with
`#inspect` (or `#to_s`, with `inspect: false`), and `inspected` is `true`.

## Options

| Option | Default | Effect |
|---|---|---|
| `label:` | inferred from a Symbol | A label for the record. A String or Symbol; anything else gives no label. |
| `inspect:` | `true` | For a value with no JSON form, `true` renders it with `#inspect`, `false` with `#to_s`. JSON-native values are unaffected. |
| `log:` | `false`, or `true` if `logger:` is given | `true` also writes the record to `Rails.logger` (or `logger:`). `false` never logs, even if `logger:` is given. |
| `logger:` | none | A `Logger` to also write the record to. Anything other than a `Logger` raises `Lba::InvalidLoggerOptionError`. |
| `sink:` | this run's file | A path or IO to write to instead. |

```ruby
Lba.val name, label: "Name", inspect: false
Lba.val :name, log: true
Lba.val :name, logger: Logger.new($stderr)
```

A logged record is the same JSON as the one written to the sink, at `debug`
level. The sink is always written; logging is an addition, not a replacement.
Outside Rails there is no default logger, so `log: true` logs nothing unless
`logger:` is also given.

An unknown option, including loba's `production:`, `logdev:`, and `out:`, raises
Ruby's `ArgumentError` at the call.

## Limits

To keep a record, and the cost of making it, bounded:

- Strings longer than 500 characters are cut to 500, followed by
  `" [+N chars]"`. Text from `#inspect` or `#to_s` is cut the same way.
- Arrays and Hashes keep their first 50 entries, followed by one entry (an Array)
  or key (a Hash) counting the rest.
- Nesting deeper than 5 levels is rendered as text.
- Each call site writes at most 500 records a minute. Calls past that write
  nothing, and skip evaluating and serializing their value. The first call to
  that site after the minute, or the process exiting normally, writes one record
  noting how many calls were skipped:

  ```json
  {"type":"val","site":"app/models/order.rb:55","suppressed":true,"suppressed_count":1250}
  ```

  A process killed without running its exit handlers (`kill -9`, or `exit!`)
  loses that last count.

`truncated` is `true` whenever any of these cut a value short.

## Errors

A Symbol that names nothing, or names a method that raises, doesn't break the
code being traced. The record keeps its call-site fields and label and records
the error instead of a value:

```json
{"label":"usr","error":"NameError: undefined local variable or method 'usr' for main"}
```

Exceptions outside `StandardError`, such as `Interrupt`, are not caught.

## Environment notes

`Lba.val` does nothing inside a Rails production environment, and there is no
override. Unlike loba's `$stdout` line, a record is written to a file meant to
be read later, so in production it could persist secrets or personal data
indefinitely.

## Caution: what gets recorded

- A value is written as-is. Nothing is filtered or redacted, so be deliberate
  about tracing passwords, tokens, or personal data, and about who can read the
  sink.
- A Symbol argument is evaluated as code in the caller. Pass Symbols you wrote,
  never one built from outside input.

## Differences from loba

- Records are JSON lines in a file, not colored text on `$stdout`.
- There is no `production:` override, and no `logdev:` or `out:`.
- `inspect:` only affects values with no JSON form; loba applied it to every
  value.
- A value given without a label records `label: null`, where loba printed
  `[unknown value]`.
