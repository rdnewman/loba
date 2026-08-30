# Lba

Structured, AI-consumable trace-debugging.

Lba is a successor to [loba](https://github.com/rdnewman/loba), rebuilt for a
different primary reader: an AI coding agent (or a human pairing alongside one)
rather than a human eyeballing colorized `$stdout` scrollback.

Status: early build, not yet released.

## Overview

Lba statements (`Lba.val`, `Lba.ts`) are terse, minimally-invasive, and meant to be
removed when you're done — same ethos as loba. Where loba writes a single
colorized text line, Lba appends one structured JSON record per line to a
per-run log file, so the trace can be aggregated, diffed across runs, and queried
by the `lba` CLI instead of read raw.

More to come as the build proceeds — see the project plan.
