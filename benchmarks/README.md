<!-- SPDX-License-Identifier: BSD-3-Clause -->
# `go-ruby-rack` library-level benchmark harness

Reproducible, cross-runtime benchmark of the **pure-Go `go-ruby-rack/rack`
library** against the reference Ruby runtimes (MRI, MRI + YJIT, JRuby,
TruffleRuby) each running the real **`rack` 3.2.6** gem. It measures the
**library primitives** through their Go API, isolated from the rbgo interpreter,
so the numbers answer: *is the pure-Go implementation as fast as the reference
runtime's own `rack`?*

## Layout

- `go/`           — self-contained Go driver; `go.mod` pins the published library
  by pseudo-version (no `replace`).
- `ruby/rack.rb`  — the equivalent workload over the real `rack` gem;
  `ruby/_harness.rb` is the shared timer.
- `run.sh`        — verifies the Go output is byte-identical to MRI, then runs
  every available runtime and prints one Markdown table per sub-benchmark
  (ns/op + ratio vs MRI).

## Run

```sh
bash benchmarks/run.sh
```

Environment knobs: `OUTER` (timed passes, default 25), `WARM` (untimed warm-up
passes, default 3), and `RUBY`/`JRUBY`/`TRUFFLERUBY` to select runtime binaries.

## Operations

Nine representative primitives from Rack's pure-compute surface, over fixed
inputs present in **both** go-ruby-rack and `rack` 3.2.6:

- `escape` / `unescape` — `application/x-www-form-urlencoded` URL escaping of a
  realistic form value (spaces, reserved bytes, multi-byte UTF-8).
- `escape_html` — the five-character HTML-entity escape (`&`, `<`, `>`, `"`,
  `'`). (`unescape_html` is omitted: it is not part of `Rack::Utils` 3.2.6.)
- `parse_query` / `build_query` — a flat query string with repeated (array) keys
  and `%`/`+`-encoded values, and its inverse.
- `parse_nested_query` / `build_nested_query` — a `foo[bar][]=…` nested body into
  structural `Hash`/`Array`/`String`/`nil`, and its inverse.
- `request` — build a `Rack::Request` from a fixed env `Hash` and read a fixed
  set of accessors (`request_method`, `host`, `port`, `scheme`, `ssl?`,
  `media_type`, `xhr?`, `url`, …).
- `response` — build a `Rack::Response`, `write` a body, and `finish` it into the
  SPEC `[status, headers, body]` tuple (content-length filled in).

## Method

Each process runs `WARM` untimed passes (to let the JVM/GraalVM JITs warm up),
then `OUTER` timed passes of a fixed inner loop, timed with a monotonic clock;
the **best** pass is reported as **ns/op**. Interpreter start-up is outside the
timed region. The Go driver and the Ruby script build **identical inputs**, and
every op's output is checked **byte-identical to MRI** (via the `check` mode's
hex dump — for the structural ops, through a length-prefixed canonical
serialiser shared by both drivers) before any timing is recorded. Results are
published, dated, in [`../docs/performance.md`](../docs/performance.md).
