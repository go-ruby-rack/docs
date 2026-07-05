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
| **Go** | 1.26.4 (`CGO_ENABLED=0`), library `github.com/go-ruby-rack/rack v0.0.0-20260704053028-640136bb67e7` |
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
even the JIT. **go-ruby-rack beats MRI + YJIT on 8 of the 9 ops.** The lone
exception is `escape_html`, where `Rack::Utils.escape_html` dispatches into a
C-implemented core (`cgi/escape`) that YJIT keeps ~1.1× ahead of the pure-Go
routine — which itself still matches plain MRI.

| Op | go-ruby (ns/op) | MRI + YJIT (ns/op) | go vs YJIT |
| --- | ---: | ---: | ---: |
| `escape` | 250.6 | 5146.0 | **20.5× faster** |
| `unescape` | 117.3 | 5651.0 | **48.2× faster** |
| `escape_html` | 174.0 | 154.0 | 0.89× (YJIT 1.13× faster) |
| `parse_query` | 1761.0 | 8775.0 | **4.98× faster** |
| `build_query` | 780.6 | 5434.5 | **6.96× faster** |
| `parse_nested_query` | 1716.7 | 6747.5 | **3.93× faster** |
| `build_nested_query` | 999.8 | 7519.0 | **7.52× faster** |
| `request` | 2282.7 | 8886.5 | **3.89× faster** |
| `response` | 859.4 | 2569.5 | **2.99× faster** |

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
| **go-ruby (pure Go)** | 250.6 | 0.05× |
| MRI | 5174.4 | 1.00× |
| MRI + YJIT | 5146.0 | 0.99× |
| JRuby | 2390.7 | 0.46× |
| TruffleRuby | 3868.8 | 0.75× |

#### unescape

`Rack::Utils.unescape` — the inverse of `escape`.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 117.3 | 0.02× |
| MRI | 5563.0 | 1.00× |
| MRI + YJIT | 5651.0 | 1.02× |
| JRuby | 3491.8 | 0.63× |
| TruffleRuby | 4020.3 | 0.72× |

#### escape_html

`Rack::Utils.escape_html` — the five-character HTML-entity escape (`&`, `<`, `>`,
`"`, `'`). MRI/YJIT dispatch to a C core here, so this is the closest race.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 174.0 | 0.91× |
| MRI | 191.2 | 1.00× |
| MRI + YJIT | 154.0 | 0.81× |
| JRuby | 205.4 | 1.07× |
| TruffleRuby | 1970.6 | 10.31× |

#### parse_query

`Rack::Utils.parse_query` — a flat query string (repeated array keys, `%`/`+`
values, a valueless key) into a `key → value(s)` map.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 1761.0 | 0.17× |
| MRI | 10474.5 | 1.00× |
| MRI + YJIT | 8775.0 | 0.84× |
| JRuby | 4429.6 | 0.42× |
| TruffleRuby | 14402.7 | 1.38× |

#### build_query

`Rack::Utils.build_query` — the inverse of `parse_query`.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 780.6 | 0.11× |
| MRI | 6895.5 | 1.00× |
| MRI + YJIT | 5434.5 | 0.79× |
| JRuby | 2551.9 | 0.37× |
| TruffleRuby | 6574.3 | 0.95× |

#### parse_nested_query

`Rack::Utils.parse_nested_query` — a `foo[bar][]=…` nested body into structural
`Hash`/`Array`/`String`/`nil`.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 1716.7 | 0.19× |
| MRI | 9136.5 | 1.00× |
| MRI + YJIT | 6747.5 | 0.74× |
| JRuby | 3450.2 | 0.38× |
| TruffleRuby | 6079.9 | 0.67× |

#### build_nested_query

`Rack::Utils.build_nested_query` — the inverse of `parse_nested_query`.

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 999.8 | 0.11× |
| MRI | 9097.0 | 1.00× |
| MRI + YJIT | 7519.0 | 0.83× |
| JRuby | 3378.5 | 0.37× |
| TruffleRuby | 8363.5 | 0.92× |

#### request

Build a `Rack::Request` from a fixed env `Hash` and read a fixed set of accessors
(`request_method`, `host`, `port`, `scheme`, `ssl?`, `media_type`, `xhr?`,
`url`, …).

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 2282.7 | 0.17× |
| MRI | 13539.0 | 1.00× |
| MRI + YJIT | 8886.5 | 0.66× |
| JRuby | 6765.8 | 0.50× |
| TruffleRuby | 11296.8 | 0.83× |

#### response

Build a `Rack::Response`, `write` a body, and `finish` it into the SPEC
`[status, headers, body]` tuple (content-length filled in).

| Runtime | ns/op | vs MRI |
| --- | ---: | ---: |
| **go-ruby (pure Go)** | 859.4 | 0.21× |
| MRI | 4126.0 | 1.00× |
| MRI + YJIT | 2569.5 | 0.62× |
| JRuby | 2007.2 | 0.49× |
| TruffleRuby | 4123.0 | 1.00× |

## Reproduce

```sh
bash benchmarks/run.sh
```

The script re-verifies byte-identical parity with MRI, then re-runs every
available runtime. Knobs: `OUTER` (timed passes, default 25), `WARM` (warm-up
passes, default 3), and `RUBY`/`JRUBY`/`TRUFFLERUBY` to select binaries.
