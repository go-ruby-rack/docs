# go-ruby-rack documentation

**Ruby's Rack — the SPEC value types and the pure-compute core of the `rack` gem — in pure Go, no cgo.**

`go-ruby-rack/rack` is a faithful, pure-Go (zero cgo) reimplementation of the
**deterministic core** of Ruby's `Rack` (Rack 3.x), matching the reference MRI
`rack` gem byte-for-byte. The module path is `github.com/go-ruby-rack/rack`.

It shapes a Rack environment, parses and builds query strings and cookies,
escapes and unescapes URI/HTML, maps HTTP status codes, and produces the
`[status, headers, body]` SPEC tuple — **without any Ruby runtime**. It is a
**standalone, reusable** library importable by any Go program, and the Rack
backend bound into [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby)
by `rbgo` — a sibling of [go-ruby-regexp](https://github.com/go-ruby-regexp/regexp),
[go-ruby-erb](https://github.com/go-ruby-erb/erb) and
[go-ruby-yaml](https://github.com/go-ruby-yaml/yaml). The dependency runs the
other way: this library has **no dependency on the Ruby runtime**.

!!! success "Status: complete — MRI byte-exact"
    A faithful pure-Go port of Rack's pure-compute surface, validated by a
    **differential oracle** against the system `ruby` with the `rack` gem —
    results compared byte-for-byte — at 100% coverage, `gofmt` + `go vet` clean,
    CI green across the six 64-bit Go targets and three OSes.

!!! note "What it is — and isn't"
    Shaping the env hash, parsing parameters and cookies, escaping, status-code
    mapping and assembling the response tuple are all fully deterministic and
    need **no interpreter**, so they live here as pure Go. The HTTP server —
    `Rack::Handler`, the socket accept loop, TLS — is the **host's** job and is
    out of scope. Reading the request body is one explicit seam: the host
    supplies an [`Input`](api.md#the-bodyinput-seam) backed by whatever IO it
    has, so this library never touches the network.

## Quick taste

```go
// Parse a nested query string into structural types.
p, _ := rack.ParseNestedQuery("user[name]=ada&user[langs][]=go", "&",
    rack.DefaultParamDepthLimit)
p.Get("user") // *rack.Params {"name"=>"ada", "langs"=>["go"]}

// Shape a request over a Rack env, then build a SPEC response tuple.
req := rack.NewRequest(rack.Env{
    rack.RequestMethod: "GET",
    rack.PathInfo:      "/search",
    rack.QueryString:   "q=hello+world",
    rack.HTTPHost:      "example.com",
    rack.RackURLScheme: "https",
})
req.URL() // https://example.com/search?q=hello+world

res := rack.NewResponseString("Hello", 200, nil)
res.SetContentType("text/plain")
status, headers, body := res.Finish() // 200, *Headers, [Hello]
```

## Repositories

| Repo | What it is |
| --- | --- |
| [`rack`](https://github.com/go-ruby-rack/rack) | the library — Rack's compute core in pure Go |
| [`docs`](https://github.com/go-ruby-rack/docs) | this documentation site (MkDocs Material, versioned with mike) |
| [`go-ruby-rack.github.io`](https://github.com/go-ruby-rack/go-ruby-rack.github.io) | the organization landing page (Hugo) |
| [`brand`](https://github.com/go-ruby-rack/brand) | logo and brand assets |

## Principles

- **Pure Go, `CGO_ENABLED=0`** — trivial cross-compilation, a single static
  binary, no C toolchain.
- **MRI byte-exact.** Output matches the reference `rack` gem exactly, not
  approximately, validated by a differential oracle against the `ruby` binary.
- **Standalone & reusable.** Extracted from rbgo's internals; no dependency on
  the Ruby runtime — the dependency runs the other way.
- **100% test coverage** is the target, enforced as a CI gate, across 6 arches
  and 3 OSes.

## Where to go next

- [Why pure Go](why.md) — why this slice of Rack is deterministic enough to live
  as a standalone, interpreter-independent Go library.
- [Usage & API](api.md) — the public surface and worked examples.
- [Roadmap](roadmap.md) — what is done and what is out of scope by design.

Source lives at [github.com/go-ruby-rack/rack](https://github.com/go-ruby-rack/rack).
