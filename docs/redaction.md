# Value redaction (design; not built yet)

Status: design agreed 2026-11-27, not yet built. Until it is, `Loba.val` writes every
value as given; nothing is masked.

## Why

`Loba.val` writes values from the caller's scope to a file meant to be read later,
often by an AI agent, and the file can leave the machine: committed, if its directory
(`tmp/loba/runs/` in Rails, `.loba/runs/` otherwise, or wherever `LOBA_SINK` or `sink:`
points) isn't ignored by git, or pasted into an issue. A secret written there can't be taken back
by anything that reads the file, so loba masks it before writing.

The bar: wherever loba has a name for a value, it checks that name against the
application's own list of sensitive names, and the gaps that remain are listed below.
This is a partial mitigation, not a guarantee that secrets never reach a record.

## Sensitive names

The list is the union of:

- In Rails, the application's `config.filter_parameters`.
- Always, a built-in list: the one `rails new` writes (Rails 8.1.3.1):
  `:passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :cvv, :cvc`.
- In Rails, each loaded ActiveRecord model's `encrypted_attributes` and the entries
  its `filter_attributes` has beyond the global list, as bare names: `encrypts :diagnosis` on `Patient` masks a
  `diagnosis` key in any value, such as `patient.attributes`.

A name is matched the way `ActiveSupport::ParameterFilter` matches a key, and loba
implements this itself, with no ActiveSupport dependency:

- A String or Symbol entry matches any name containing it, ignoring case (`:passw`
  matches `"user_password"`). A Regexp entry is used as given, so it ignores case only
  if it says so (`/pass/` doesn't match `"PASSWORD"`).
- An entry containing a `.` (a Regexp too, if its source has `\.`) is matched against
  the dotted path of Hash keys built from the top, and still as a substring: besides
  `{patient: {diagnosis: ...}}`, `"patient.diagnosis"` also masks
  `{admin: {patient: {diagnosis: ...}}}` and `{outpatient: {diagnosis_code: ...}}`.
  An Array in between adds nothing to the path.
- A Proc entry is called, when no other entry matched, on copies of the name and the
  value, for a value that isn't a Hash or Array; whatever it changes on the copy is
  written, and its return value is ignored. A Proc that doesn't take exactly two
  arguments is called with a third: the whole recorded value.
- Beyond Rails: a name is also tried in snake_case (`apiKey` as `api_key`,
  `X-Api-Key` as `x_api_key`), so `:_key` matches camelCase keys.

The decision for each name is cached for as long as the list stays the same; the list
can grow while the program runs (a model declaring `encrypts` adds to it when it loads).

## Where loba checks

| Point | Name checked | Example masked |
|---|---|---|
| Before evaluating a Symbol argument | the Symbol, and the explicit label if given | `Loba.val :password`, `Loba.val :token, label: "t"` |
| Before recording any other argument | the argument's source text at the call's file and line | `Loba.val user.ssn` |
| At each Hash key during serialization | the key, and its dotted path | `{user: {password: ...}}` |
| Text loba renders without walking into it | any String or Symbol entry appearing in the text | `#<struct password="...">`, a Hash nested past the depth limit |

A Symbol argument whose name matches is never evaluated, so an error that would carry
its value (`Loba.val :"Integer(password)"` fails with `invalid value for Integer():
"s3cret"`) never happens. A Hash value whose key
matches is never serialized. Text rendered with `#inspect` or `#to_s` is masked whole
if a sensitive name appears in it, which can mask more than needed: a model's
`#inspect` showing `password_digest: [FILTERED]` is masked entirely.

## In a record

A masked part's value is `"[FILTERED]"`, and the record lists it in `redacted`, which
follows `value_type`:

    "redacted": [{"path": ["user", "password"], "by": "name"}]

`by` says why: `"name"` (a key, label, or argument matched), `"text"` (a sensitive
name appeared in rendered text), or `"proc"` (a Proc from the list changed the value;
the value is whatever the Proc left, not the mask). A path is listed only when
something was masked or changed; a record with nothing masked has no `redacted`.

- A masked part has no `cut`, `rendered`, or `errors` entry of its own: it was never
  rendered. A part masked by `"text"` keeps no `rendered` entry either.
- `value_type` is kept, except for a Symbol argument that was never evaluated.
- In `collided`, a pair's value text is masked when its key matches.
- A Proc that raises: the value is `"[FILTERED]"` and the message goes in `errors`.
- The record written to `Rails.logger` (`log: true`) is the same masked record.

## On by default, no override

Redaction is always on. There is no per-call or global way to turn it off, or to add
names outside Rails' configuration.

## Not covered

- A value with no name, or with a name that isn't on the list: `Loba.val creds`
  holding a password. Recognizing secrets by content (`sk_live_...`, a JWT, a URL with
  a password) isn't done.
- Plain objects rendered by `#inspect`, unless a sensitive name appears in the text:
  `#<Conn url="postgres://app:s3cret@db">` names nothing on the list, so it is written
  whole.
- Error messages from evaluating a name that didn't match, and errors raised while
  rendering a value.
- Regexp entries applied to rendered text match only as well as they fit free text, and
  Proc entries aren't applied to text at all.
- Code without a source file (`eval`, irb): only the Symbol and label are checked.
