# Lba

Structured, AI-consumable trace-debugging.

Lba's primary reader is an AI coding agent (or a human pairing alongside one),
not a human scanning terminal output.

Status: early build, not yet released.

_This documentation was drafted with AI assistance and reviewed by the author._

## Overview

Lba statements (`Lba.val`, `Lba.ts`) are terse, minimally-invasive, and meant to be
removed when you're done. Each one appends a structured JSON record, one per
line, to a per-run log file, so the trace can be aggregated, diffed across runs,
and queried by the `lba` CLI (planned) instead of read raw.

## Usage

### Value records: `Lba.val`

Records a value, with the class, method, file, and line it was called from:

```ruby
class HelloWorld
  def hello(name)
Lba.val :name       # put Lba statements at the far left to help remember to remove them
    "Hello, #{name}!"
  end
end
HelloWorld.new.hello("Charlie")
```

appends a line like this to the run's file (shown here with some fields left
out; run as `ruby hello_world.rb`, so `file` is the path Ruby loaded it by):

```json
{"type":"val","label":"name","file":"hello_world.rb","line":3,"class_name":"HelloWorld","method_name":"hello","value_type":"String","value":"Charlie"}
```

A Symbol names something in the caller (a local, an instance variable, a method,
or an expression); anything else is recorded as given. `label:` sets the
record's label either way. `Lba.val` is shorthand for `Lba.value`.

A Symbol is evaluated as code in the caller, so pass only Symbols you wrote,
never one built from outside input (see [docs/val.md](docs/val.md#caution-what-gets-recorded)).

See [docs/val.md](docs/val.md) for the full record format, options (including
logging to `Rails.logger` or any `Logger`), where records are written, and
limits.

### Timestamp records: `Lba.ts`

Records a checkpoint: that a line was reached, with the same caller details and
the seconds since the previous checkpoint:

```ruby
class Cart
  def checkout
Lba.ts
    charge_card
Lba.ts label: "card charged"
  end
end
```

appends two lines like these (again with some fields left out):

```json
{"type":"ts","label":null,"line":3,"class_name":"Cart","method_name":"checkout","site_seq":1,"since_prev_ts":null}
{"type":"ts","label":"card charged","line":5,"class_name":"Cart","method_name":"checkout","site_seq":1,"since_prev_ts":0.25351782900543185}
```

`since_prev_ts` is `null` for a run's first checkpoint; `site_seq` counts how
many times each line has been reached. `label:` names a checkpoint. `Lba.ts` is
shorthand for `Lba.timestamp`.

See [docs/ts.md](docs/ts.md) for the full record format, options, and limits.

## Environment notes

Lba statements are meant for development and test. In a production environment
they do nothing (inside Rails, `Rails.env.production?`; outside it, `RACK_ENV`,
`APP_ENV`, or `RAILS_ENV` set to `production`), and there is no override:
records are written to files meant to be read later, and captured values are
stored as-is, so leaving tracing on in production could persist secrets or
personal data indefinitely.

Records go to `tmp/lba/runs/` under `Rails.root` in Rails, or `.lba/runs/` under
the current directory otherwise. Add that directory to `.gitignore`.

## Installation

Lba isn't published yet. To try it from source, add to your Gemfile:

```ruby
group :development, :test do
  gem "lba", git: "https://github.com/rdnewman/lba"
end
```

Then run `bundle install`. Lba needs Ruby 3.2 or newer.

## Development

After checking out the repo, run `bundle install`. Then:

- `bin/verify` runs every check a change should pass: the specs, rubocop, and a
  check that every public object has YARD docs with no rubocop directive leaked
  into them. Add `--performance` to include the timing checks. It runs them all
  even if one fails, and exits nonzero if any did.
- `bundle exec rspec` runs the specs.
- `bundle exec rspec --tag performance` runs the timing checks, which are left
  out of the default run because their results depend on the machine.
- `bundle exec rubocop` checks style.
- `bundle exec yard` builds the API documentation.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).
