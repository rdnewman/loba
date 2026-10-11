# Value records: `Lba.val`

`Lba.val` records a value, along with the class, method, file, and line it was
called from, as one JSON object per line in the current run's sink.

```ruby
Lba.val :var_sym                     # a Symbol names something in the caller: a local, an instance variable, a method...
Lba.val some_value                   # anything else is recorded as given
Lba.val some_value, label: "Name"    # a label for a value that can't name itself
```

`Lba.val` is shorthand for `Lba.value`.

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
{"type":"val","label":"name","file":"hello_world.rb","line":3,"class_name":"HelloWorld","method_name":"hello","method_type":"instance","value_type":"String","truncated":false,"value":"Charlie"}
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
{"label":null,"value_type":"String","value":"Charlie"}
```

A value given directly can't name itself, so `label` is `null`.

### Example 4: a value given directly, with a label

```ruby
Lba.val name, label: "Name"
```

```json
{"label":"Name","value_type":"String","value":"Charlie"}
```

## Where records go

Each process run writes to its own file, named for its run id:

- inside Rails: `tmp/lba/runs/<run_id>.jsonl` under `Rails.root`
- otherwise: `.lba/runs/<run_id>.jsonl` under the current directory

The `LBA_SINK` environment variable overrides that path for the whole process
(an empty `LBA_SINK` is ignored), and the `sink:` option overrides it for one
call, with a path (a String or `Pathname`) or any IO (such as `$stdout` or a
`StringIO`). If the directory can't be created or written to, records go to
`$stdout` instead.

Records hold captured values as-is, so a file lba creates is readable and
writable only by its owner (mode `0600`), as are the directories it creates
for a run's own file (`0700`). Files and directories that already exist keep
their permissions. If anything, even a symlink, is already at a run's own file
path when the run first writes there, records go to `$stdout` instead.

If a record still can't be written (a full disk, a read-only file, a closed
IO), it is skipped, and the first such failure in the process is reported once
on `$stderr`. The code being traced keeps running.

A skipped record shouldn't look like code that never ran, so the next record
that is written to the same sink notes what was missed, in `unwritten`:

```json
{"seq":4,"type":"ts","unwritten":{"count":2,"first_seq":2,"last_seq":3,"error":"Errno::EACCES: Permission denied @ rb_sysopen - log/trace.jsonl"},"label":"after recovery"}
```

If no later record reaches that sink, the process reports the loss when it
exits normally instead, on `$stderr`:

```text
lba: 2 records couldn't be written to "log/trace.jsonl" (first error: Errno::EACCES: Permission denied @ rb_sysopen - log/trace.jsonl)
```

Inside Rails, the default is used only once the app has booted (`Rails.root` is
set); before that, records go under the current directory.

A forked child process, such as a Puma or Unicorn worker, starts its own run and
file.

## The record

Fields come in this order on every line: what and where first, then what
describes the value, then the value (the one field with no size limit), then
bookkeeping that repeats from line to line.

| Field | Meaning |
|---|---|
| `seq` | Order of this record among all records in the run |
| `type` | `"val"` |
| `unwritten` | Present only when earlier records to this sink couldn't be written: their `count`, the `first_seq` and `last_seq` they fell between, and the first `error` (see [Where records go](#where-records-go)) |
| `label` | The given or inferred label, or `null` |
| `file`, `line` | Where `Lba.val` was called; `file` is the path Ruby loaded that file by, usually absolute inside an app |
| `class_name` | The caller's class, or the class itself inside a class method; `"<anonymous class>"` for an unnamed one |
| `method_name` | The caller's method; `"<anonymous method>"` outside any method |
| `method_type` | `"instance"` or `"class"` |
| `site_seq` | Order of this record among records from the same call site (file and line) |
| `diff` | Seconds since the previous record from the same call site, exactly the difference between their `mono_time` values; `null` for the first |
| `value_type` | The value's class name |
| `rendered` | Present only when some part of the value is recorded as text instead of as itself: one `{"path", "as"}` per part, where `as` says why (see below). The text can look exactly like a real String; this says which parts aren't |
| `truncated` | `true` if any part of the value was cut short (see [Limits](#limits)) |
| `errors` | Present only when evaluating the Symbol, or rendering any part of the value, raised: one `{"path", "message"}` per failure. Without `value`, nothing could be recorded; with it, only part couldn't (see [Errors](#errors)). A `path`, here and in `rendered`, is the part's Array indexes and Hash keys from the top; `[]` is the whole value |
| `value` | The value, as JSON (see below) |
| `wall_time` | Seconds since the epoch, when recorded |
| `mono_time` | A monotonic clock reading, unaffected by system clock changes |
| `run_id` | This process run, e.g. `20260926T210626Z-894825-b10f3e7a` |
| `schema` | Record format version, currently `1` |

Strings, numbers, `true`, `false`, `nil`, Arrays, and Hashes are recorded as
JSON, including inside each other; Symbols are recorded as JSON strings, and
Hash keys always become JSON strings. Anything else is rendered as text with
`#inspect` (or `#to_s`, with `inspect: false`), and `rendered` names it with
`as` `"inspect"` (or `"to_s"`).

JSON can't hold some values exactly, so these are recorded as text too, and
named in `rendered`:

- A String that isn't text (binary data, or invalid UTF-8) is recorded as its
  `#inspect` text, e.g. `"\"\\xFF\\xFE\""`, with `as` `"not_utf8"`. A String in
  another encoding that converts to UTF-8 is recorded converted.
- `NaN` and `Infinity` are recorded as `"NaN"`, `"Infinity"`, and `"-Infinity"`,
  with `as` `"non_finite"`.
- A container nested more than 5 levels deep is rendered whole as text, with
  `as` `"too_deep"` (see [Limits](#limits)).

For example, `Lba.val :order` where `order` is
`{total: Float::NAN, note: "NaN", items: [1, Point.new(2)]}`:

```json
{"label":"order","value_type":"Hash","rendered":[{"path":["total"],"as":"non_finite"},{"path":["items",1],"as":"inspect"}],"truncated":false,"value":{"total":"NaN","note":"NaN","items":[1,"#<struct Point x=2>"]}}
```

`"total"` and `"note"` look the same in `value`; `rendered` says only `"total"`
was a `NaN`.

## Options

| Option | Default | Effect |
|---|---|---|
| `label:` | inferred from a Symbol | A label for the record. A String or Symbol; anything else gives no label. |
| `inspect:` | `true` | For a value with no JSON form, `true` renders it with `#inspect`, `false` with `#to_s`. JSON-native values are unaffected. |
| `log:` | `false`, or `true` if `logger:` is given | `true` also writes the record to `Rails.logger` (or `logger:`). `false` never logs, even if `logger:` is given. |
| `logger:` | none | A `Logger` to also write the record to. Anything other than a `Logger` raises `Lba::InvalidLoggerOptionError`. |
| `sink:` | this run's file | A path (String or `Pathname`) or IO to write to instead. |

```ruby
Lba.val name, label: "Name", inspect: false
Lba.val :name, log: true
Lba.val :name, logger: Logger.new($stderr)
```

A logged record is the same JSON as the one written to the sink, at `debug`
level. The sink is always written; logging is an addition, not a replacement.
The record counting a capped site's skipped calls (see [Limits](#limits)) is
logged too, with the logging options of that site's latest call. Outside Rails
there is no default logger, so `log: true` logs nothing unless `logger:` is
also given.

An unknown option raises Ruby's `ArgumentError` at the call.

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
  {"seq":501,"type":"val","file":"app/models/order.rb","line":55,"suppressed":true,"suppressed_count":1246,"wall_time":1790526416.5963955,"mono_time":1061.0,"run_id":"20260927T162656Z-1108765-4c1d93a0","schema":1}
  ```

  It has the same `seq`, `type`, and closing fields as every record and takes
  the next `seq`, but has no `site_seq`, caller details, or value. Skipped calls
  take no numbers, so `seq` and `site_seq` never skip.

  A process killed without running its exit handlers (`kill -9`, or `exit!`)
  loses that last count.

`truncated` is `true` whenever any of these cut a value short.

## Errors

A Symbol that names nothing, or names a method that raises, doesn't break the
code being traced. The record keeps its call-site fields and label and records
the error in `errors` instead of a value. A `path` of `[]` means the whole
value:

```json
{"label":"usr","errors":[{"path":[],"message":"NameError: undefined local variable or method 'usr' for main"}]}
```

The same happens when the value can't be rendered as text: its `#inspect` (or
`#to_s`, with `inspect: false`) raises, or it has none, like a `BasicObject`.
There is no fallback from one to the other.

```json
{"label":"invoice","errors":[{"path":[],"message":"NoMethodError: undefined method 'name' for nil"}]}
```

When only part of an Array or Hash can't be rendered, the rest is kept. Each
part that couldn't be is recorded as `"(unrenderable)"`, and has its own entry
in `errors`, whose `path` gives its position: Array indexes and Hash keys, from
the outside in.

```json
{"label":"items","value_type":"Array","truncated":false,"errors":[{"path":[0],"message":"NoMethodError: undefined method 'inspect' for an instance of BasicObject"},{"path":[2],"message":"ArgumentError: boom"}],"value":["(unrenderable)",1,"(unrenderable)"]}
```

So `errors` is always the sign that something couldn't be recorded; a record
without it was recorded in full. Exceptions outside `StandardError`, such as
`Interrupt`, are not caught.

## Environment notes

`Lba.val` does nothing in a production environment, and there is no override.
Inside Rails, that means `Rails.env.production?`; outside Rails, any of
`RACK_ENV`, `APP_ENV`, or `RAILS_ENV` set to `production`. A record is written
to a file meant to be read later, so in production it could persist secrets or
personal data indefinitely.

## Caution: what gets recorded

- A value is written as-is. Nothing is filtered or redacted, so be deliberate
  about tracing passwords, tokens, or personal data, and about who can read the
  sink.
- A Symbol argument is evaluated as code in the caller. Pass Symbols you wrote,
  never one built from outside input.
