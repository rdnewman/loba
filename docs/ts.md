# Timestamp records: `Loba.ts`

`Loba.ts` records a checkpoint: that a line of code was reached, with the class,
method, file, and line it was called from, and the seconds since the previous
checkpoint, as one JSON object per line in the current run's sink.

```ruby
Loba.ts                          # a checkpoint
Loba.ts label: "card charged"    # a checkpoint with a name
```

`Loba.ts` is shorthand for `Loba.timestamp`.

## Examples

Each example shows the fields that matter to it; every record also carries the
fields listed under [The record](#the-record).

### Example 1: timing a stretch of code

```ruby
class Cart
  def checkout
Loba.ts              # put Loba statements at the far left to help remember to remove them
    charge_card
Loba.ts label: "card charged"
  end
end
```

```json
{"seq":1,"type":"ts","label":null,"line":3,"class_name":"Cart","method_name":"checkout","site_seq":1,"since_prev_ts":null}
{"seq":2,"type":"ts","label":"card charged","line":5,"class_name":"Cart","method_name":"checkout","site_seq":1,"since_prev_ts":0.25351782900543185}
```

The first checkpoint of a run has no previous one, so its `since_prev_ts` is
`null`. The second shows `charge_card` took about a quarter of a second.

### Example 2: counting how often a line is reached

```ruby
def import(rows)
  rows.each do |row|
Loba.ts
  end
end
```

Each pass writes a record from the same line, and `site_seq` counts them: 1, 2,
3, and so on. A checkpoint inside a block reports the method around it.

## Where records go

The same place as `Loba.val`'s records: this run's file, `LOBA_SINK`, or the
`sink:` option (see [Where records go](val.md#where-records-go)). Unless a
`sink:` sends them elsewhere, checkpoints and values from one run share one
file, and they always share one `seq`.

## The record

Fields come in this order on every line, as with
[`Loba.val`](val.md#the-record).

| Field | Meaning |
|---|---|
| `seq` | Order of this record among all records in the run, values included: the order calls reached loba. Lines can be out of `seq` order when one loba call runs inside another (a Symbol naming a method that calls loba, say) or calls run in several threads; sort by `seq` to read them in call order. |
| `type` | `"ts"` |
| `unwritten` | Present only when earlier records to this sink couldn't be written: their `count`, the `seq` of the first and last of them (`first_seq`, `last_seq`), and the first `error` (see [Where records go](val.md#where-records-go)) |
| `label` | The given label, or `null` |
| `file`, `line` | Where `Loba.ts` was called; `file` is the path Ruby loaded that file by, usually absolute inside an app |
| `class_name` | The caller's class, or the class itself inside a class method; `"<anonymous class>"` for an unnamed one |
| `method_name` | The caller's method; `"<anonymous method>"` outside any method |
| `method_type` | `"instance"` or `"class"` |
| `site_seq` | Order of this record among checkpoints from the same call site (file and line) |
| `since_prev_ts` | Seconds since the previous checkpoint anywhere in the run; `null` for the first |
| `wall_time` | Seconds since the epoch, when recorded |
| `mono_time` | A monotonic clock reading, unaffected by system clock changes |
| `run_id` | This process run, e.g. `20260930T135402Z-5-39e8b2c6` |
| `schema` | Record format version, currently `1` |

### How `since_prev_ts` is measured

- It counts from the previous **checkpoint**, from any line. A `Loba.val`
  between two checkpoints doesn't change it.
- It's exactly the difference between this record's `mono_time` and the
  previous checkpoint's.
- It's measured on the monotonic clock, so a system clock change can't make it
  wrong or negative. On Linux that clock doesn't advance while the machine is
  suspended: across a sleep, `since_prev_ts` shows only the time awake, and the
  two records' `wall_time` show the full gap.
- Calls skipped by the [limit](#limits), and the record counting them, don't
  count as a previous checkpoint. `since_prev_ts` always measures from a
  checkpoint record you can find in the file.

A value record's `diff` is different: it measures from the previous record at
the *same* call site. Checkpoint records have no `diff`.

## Options

| Option | Default | Effect |
|---|---|---|
| `label:` | none | A name for the checkpoint. A String or Symbol, stripped of surrounding spaces; anything else gives no label. Converted to UTF-8; bytes that aren't valid UTF-8 become `�` (U+FFFD). |
| `log:` | `false`, or `true` if `logger:` is given | `true` also writes the record to `Rails.logger` (or `logger:`). `false` never logs, even if `logger:` is given. |
| `logger:` | none | A `Logger` to also write the record to. When the call would log, anything other than a `Logger` raises `Loba::InvalidLoggerOptionError` (not with `log: false`, and not in production, where nothing is written). |
| `sink:` | this run's file | A path (String or `Pathname`) or IO to write to instead. |

```ruby
Loba.ts label: "reached step A"
Loba.ts log: true
Loba.ts logger: Logger.new($stderr)
```

Logging works as it does for `Loba.val`: the same JSON (except that
`unwritten` appears only in the sink), at `debug` level, in addition to the
sink. Outside Rails, `log: true` logs nothing unless `logger:`
is also given.

An unknown option raises Ruby's `ArgumentError` at the call.

## Limits

Each call site writes at most 500 checkpoints a minute, as with `Loba.val`.
Calls past that write nothing; the first call to that site after the minute, or
the process exiting (by any means but `exit!` or `kill -9`), writes one record
noting how many were skipped:

```json
{"seq":501,"type":"ts","file":"app/models/cart.rb","line":10,"suppressed":true,"suppressed_count":3,"wall_time":1790776456.2902832,"mono_time":47675.468684261,"run_id":"20260930T135416Z-5-e7905d1f","schema":1}
```

A `Loba.ts` and a `Loba.val` on the same line are separate call sites, each with
its own `site_seq` and its own limit.

## Errors

The only caller code `Loba.ts` runs is a class's own `name` method, for
`class_name`; if that fails, the class's constant name is used instead, so
`Loba.ts` has nothing to record as an error. A record that can't be written (a
full disk, a read-only file, a closed IO) is skipped. The first such failure in
a process is reported on `$stderr`, the rest are summarized when it exits, and
the next record written to that sink notes the gap in `unwritten`, as for
`Loba.val` (see [Where records go](val.md#where-records-go)). That matters for
checkpoints in particular: a skipped checkpoint must not look like a line that
was never reached. Any other error is raised at the call: one raised by a
`logger:` or IO you passed, or a bug in loba.

## Environment notes

`Loba.ts` does nothing in a production environment, and there is no override
(see [Environment notes](val.md#environment-notes) for what counts as one).
