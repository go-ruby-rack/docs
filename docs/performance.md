# Performance

`go-ruby-rack/rack` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) binds for Ruby's `rack`. This
page records where the module sits in the ecosystem-wide **per-module parity
suite** — the same discipline used across the go-ruby-* family: run the same
Ruby-visible operation through the pure-Go library and through each reference
runtime, verify output is **byte-identical to MRI** first, then time it.

!!! note "Correctness is settled; comparative timing is the next step"
    The library is **complete and MRI byte-exact** — every escaping, query-parse,
    status, cookie, media-type, byte-range and `Response#finish` case is checked
    byte-for-byte against the system `ruby` with the `rack` gem, at 100%
    coverage. A published comparative benchmark table (rbgo vs MRI / YJIT / JRuby
    / TruffleRuby, and the Go API measured directly) is **not yet run for this
    module**; this page will carry only **real, dated, measured** numbers when it
    is — nothing estimated or cherry-picked.

## What will be measured

Rack's compute surface is dominated by string work — percent-escaping, bracket
query parsing, cookie and header assembly, status-code mapping — so the parity
workload exercises exactly those hot paths:

- **escape / unescape** a corpus of URI and HTML strings
  (`Rack::Utils.escape` / `unescape` vs `Escape` / `Unescape`);
- **nested query parse** of realistic `foo[bar][]=…` form bodies
  (`Rack::Utils.parse_nested_query` vs `ParseNestedQuery`);
- **response finish** — assembling the `[status, headers, body]` tuple with
  content-length and cookies (`Rack::Response#finish` vs `Response.Finish`).

Each is run through the pure-Go library and through each reference runtime's own
`rack`; the script prints a deterministic checksum and its output is checked
**byte-identical to MRI** before any timing is recorded.

## Method (when published)

- **Runtimes:** `ruby` (MRI, the oracle) and `ruby --yjit`; `jruby` (JVM);
  `truffleruby` (GraalVM). The Go library is also measured **directly through its
  Go API**, isolating the primitive from interpreter dispatch.
- **Timing:** a fixed warm-up budget then N timed passes in one process, best
  pass reported (best, not mean, to suppress scheduler noise); interpreter
  start-up is outside the timed region.
- **Framing:** JVM/GraalVM JITs are timed cold/single-shot and can understate
  peak throughput; sub-microsecond rows carry the most relative noise and are
  read as order-of-magnitude. Every published number is a real measured value
  from a dated run on stated hardware.

The harness will live under `benchmarks/` in this repository (a self-contained Go
driver pinning the library's commit via `go.mod`, the equivalent Ruby workload,
and a `run.sh`), mirroring the sibling go-ruby-* modules.
