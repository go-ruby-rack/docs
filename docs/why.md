# Why pure Go

`go-ruby-rack/rack` reimplements the core of Ruby's `Rack` in **pure Go, with
cgo disabled**. The slice of Rack it covers is **deterministic and
interpreter-independent**: given its inputs, the result is a pure function of
those inputs — no live binding, no evaluation of arbitrary Ruby, no network.
That is exactly the part that can — and should — live as a standalone Go library,
separate from both the interpreter and the HTTP server.

## What is in scope — and what isn't

Rack is two things bolted together: a **value/compute layer** (the SPEC env
hash, parameter and cookie parsing, escaping, status-code mapping, the
`[status, headers, body]` tuple) and a **server layer** (`Rack::Handler`, the
socket accept loop, TLS). Only the first is deterministic.

- **In scope — deterministic compute.** `Rack::Utils`, `Rack::Request`,
  `Rack::Response`, `Rack::MediaType` and the header machinery are pure functions
  of their inputs. They live here as pure Go and are pinned byte-for-byte against
  the `rack` gem.
- **Out of scope — the server.** Accepting sockets, TLS and `Rack::Handler` are
  the **host's** job. Reading the request body is the one deferred point, behind
  a small [`Input`](api.md#the-bodyinput-seam) seam the host fills — so this
  library never touches the network.

## Extracted from rbgo, reusable by anyone

This library began life inside
[go-embedded-ruby](https://github.com/go-embedded-ruby/ruby)'s `rbgo`, backing
its Rack surface. It has been **extracted into a reusable standalone library** so
that:

- any Go program can import `github.com/go-ruby-rack/rack` directly, with no Ruby
  runtime;
- the dependency runs the *other* way — `rbgo` binds this module as a native
  module (the same pattern as
  [go-ruby-regexp](https://github.com/go-ruby-regexp/regexp) and
  [go-ruby-yaml](https://github.com/go-ruby-yaml/yaml)), rather than this module
  depending on the interpreter;
- the behaviour is pinned by a **differential oracle** against the system `ruby`
  with the `rack` gem, independent of any one consumer.

## Why pure Go matters here

Because the library is CGO-free, it:

- cross-compiles to every Go target with no C toolchain, and links into a single
  static binary;
- has **no dependency on the Ruby runtime** — the dependency runs the other way;
- can be differentially tested against the `rack` gem wherever `ruby` is on
  `PATH`, while the cross-arch and Windows lanes (where `ruby` is absent) still
  validate the library itself.

See [Usage & API](api.md) for the surface and [Roadmap](roadmap.md) for what is
in scope.
