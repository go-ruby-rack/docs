# Performance

`go-ruby-rack/rack` is the pure-Go library that
[`rbgo`](https://github.com/go-embedded-ruby/ruby) binds for Ruby's `rack`. This
page records the module's place in the ecosystem-wide **per-module parity
suite**: the same Ruby-visible operation is run through the pure-Go library and
through each reference runtime's own `rack` gem; the Go output is verified
**byte-identical to MRI** first, then timed.

The harness lives under [`benchmarks/`](https://github.com/go-ruby-rack/docs/tree/main/benchmarks)
in this repository — a self-contained Go driver that pins the published library
by pseudo-version (no `replace`), the equivalent Ruby workload over the real
`rack` gem, and a `run.sh` that gates on byte-identical parity before timing.

## Setup

| | |
| --- | --- |
| **Date** | 2026-07-05 |
| **Host** | Apple M4 Max, 16 cores, macOS 26.5.1 (arm64), on the host — no VM |
| **Go** | 1.26.4 (`CGO_ENABLED=0`), library `github.com/go-ruby-rack/rack v0.0.0-20260705195519-3d6eb0d8d96b` |
| **MRI** | ruby 4.0.5 +PRISM, with and without `--yjit` |
| **JRuby** | 10.1.0 (OpenJDK 25.0.2) |
| **TruffleRuby** | 34.0.1 (GraalVM CE Native, like ruby 3.4.9) |
| **`rack` gem** | 3.2.6 on every reference runtime |

**Method.** Each process runs 3 untimed warm-up passes (to let the JVM/GraalVM
JITs warm up), then 25 timed passes of a fixed inner loop, timed with a monotonic
clock; the **best** pass is reported as **ns/op** (best, not mean, to suppress
scheduler noise). Interpreter start-up is outside the timed region. Every op's
output is checked **byte-identical to MRI** before any timing is recorded — the
structural ops (`parse_*`, `request`, `response`) through a length-prefixed
canonical serialiser shared by the Go and Ruby drivers.

!!! note "Reading the numbers"
    JRuby and TruffleRuby are timed **cold / single-shot** (one short-lived
    process, best of 25 passes) and can understate their true steady-state peak;
    their columns are indicative, not their JIT ceiling. Sub-microsecond rows
    carry the most relative noise and should be read as order-of-magnitude. Every
    number below is a real measured value from the dated run above — nothing
    estimated or cherry-picked.

## Headline: pure-Go vs MRI + YJIT

Rack's compute surface is pure Ruby, so the pure-Go port is broadly far ahead of
even the JIT. **go-ruby-rack beats MRI + YJIT on all 9 ops.** The closest race is
`escape_html`, where `Rack::Utils.escape_html` dispatches into a C-implemented
core (`cgi/escape`): a two-pass `strings.Replacer` used to lose to it, but the
table-driven single-pass escaper (a 256-entry byte→entity lookup that
bulk-copies verbatim runs and returns no-escape input allocation-free) now runs
~1.5× ahead of even YJIT's C path.

| Op | go-ruby (ns/op) | MRI + YJIT (ns/op) | go vs YJIT |
| --- | ---: | ---: | ---: |
| `escape` | 245.7 | 4999.2 | **20.3× faster** |
| `unescape` | 116.2 | 5659.6 | **48.7× faster** |
| `escape_html` | 104.8 | 162.2 | **1.55× faster** |
| `parse_query` | 1798.6 | 8985.5 | **5.00× faster** |
| `build_query` | 779.9 | 5386.5 | **6.91× faster** |
| `parse_nested_query` | 1735.4 | 7001.5 | **4.03× faster** |
| `build_nested_query` | 1029.4 | 7337.5 | **7.13× faster** |
| `request` | 2310.6 | 8559.5 | **3.70× faster** |
| `response` | 854.8 | 2585.5 | **3.02× faster** |

## Full results

Nine representative primitives from Rack's pure-compute surface, over fixed
inputs present in **both** go-ruby-rack and `rack` 3.2.6. (`unescape_html` is
omitted — it is not part of `Rack::Utils` 3.2.6.) `vs MRI` is the ratio to plain
MRI (lower is faster).

#### escape

`Rack::Utils.escape` — form-encode a realistic value (spaces, reserved bytes,
multi-byte UTF-8).

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 245.7 | 0.05× |
| MRI | 5213.2 | 1.00× |
| MRI + YJIT | 4999.2 | 0.96× |
| JRuby | 2231.5 | 0.43× |
| TruffleRuby | 3844.0 | 0.74× |

#### unescape

`Rack::Utils.unescape` — the inverse of `escape`.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 116.2 | 0.02× |
| MRI | 5583.4 | 1.00× |
| MRI + YJIT | 5659.6 | 1.01× |
| JRuby | 3267.4 | 0.59× |
| TruffleRuby | 3983.9 | 0.71× |

#### escape_html

`Rack::Utils.escape_html` — the five-character HTML-entity escape (`&`, `<`, `>`,
`"`, `'`). MRI/YJIT dispatch to a C core (`cgi/escape`) here, so this is the
closest race — and the pure-Go table-driven escaper now wins it outright.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 104.8 | 0.55× |
| MRI | 191.8 | 1.00× |
| MRI + YJIT | 162.2 | 0.85× |
| JRuby | 304.4 | 1.59× |
| TruffleRuby | 2065.3 | 10.77× |

#### parse_query

`Rack::Utils.parse_query` — a flat query string (repeated array keys, `%`/`+`
values, a valueless key) into a `key → value(s)` map.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 1798.6 | 0.17× |
| MRI | 10550.5 | 1.00× |
| MRI + YJIT | 8985.5 | 0.85× |
| JRuby | 4354.3 | 0.41× |
| TruffleRuby | 13347.3 | 1.27× |

#### build_query

`Rack::Utils.build_query` — the inverse of `parse_query`.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 779.9 | 0.12× |
| MRI | 6628.0 | 1.00× |
| MRI + YJIT | 5386.5 | 0.81× |
| JRuby | 2440.7 | 0.37× |
| TruffleRuby | 6311.9 | 0.95× |

#### parse_nested_query

`Rack::Utils.parse_nested_query` — a `foo[bar][]=…` nested body into structural
`Hash`/`Array`/`String`/`nil`.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 1735.4 | 0.19× |
| MRI | 9019.5 | 1.00× |
| MRI + YJIT | 7001.5 | 0.78× |
| JRuby | 3418.7 | 0.38× |
| TruffleRuby | 5787.0 | 0.64× |

#### build_nested_query

`Rack::Utils.build_nested_query` — the inverse of `parse_nested_query`.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 1029.4 | 0.11× |
| MRI | 9012.0 | 1.00× |
| MRI + YJIT | 7337.5 | 0.81× |
| JRuby | 3417.9 | 0.38× |
| TruffleRuby | 7747.8 | 0.86× |

#### request

Build a `Rack::Request` from a fixed env `Hash` and read a fixed set of accessors
(`request_method`, `host`, `port`, `scheme`, `ssl?`, `media_type`, `xhr?`,
`url`, …).

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 2310.6 | 0.17× |
| MRI | 13675.0 | 1.00× |
| MRI + YJIT | 8559.5 | 0.63× |
| JRuby | 6967.3 | 0.51× |
| TruffleRuby | 10863.8 | 0.79× |

#### response

Build a `Rack::Response`, `write` a body, and `finish` it into the SPEC
`[status, headers, body]` tuple (content-length filled in).

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 854.8 | 0.21× |
| MRI | 4083.5 | 1.00× |
| MRI + YJIT | 2585.5 | 0.63× |
| JRuby | 2024.5 | 0.50× |
| TruffleRuby | 4284.7 | 1.05× |

## Reproduce

```sh
bash benchmarks/run.sh
```

The script re-verifies byte-identical parity with MRI, then re-runs every
available runtime. Knobs: `OUTER` (timed passes, default 25), `WARM` (warm-up
passes, default 3), and `RUBY`/`JRUBY`/`TRUFFLERUBY` to select binaries.
