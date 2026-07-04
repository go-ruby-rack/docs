# Roadmap

`go-ruby-rack/rack` is grown **test-first**, each capability differential-tested
against the `rack` gem rather than built in isolation. The deterministic,
interpreter-independent slice of Rack 3.x's pure-compute surface extracted from
rbgo's internals is **complete**.

| Stage | What | Status |
| --- | --- | --- |
| Query & parameters | `ParseQuery` / `ParseNestedQuery` bracket nesting (`foo[bar]`, `foo[]`, `x[][a]`), the array-of-hash vs nested-array subtleties, `ParameterTypeError` / `ParamsTooDeepError`, and `BuildQuery` / `BuildNestedQuery` inverses. | **Done** |
| Escaping | `Escape` / `Unescape`, `EscapePath` / `UnescapePath` (RFC 2396), `EscapeHTML` / `UnescapeHTML` — byte-identical to MRI. | **Done** |
| Status codes & headers | The full `HTTPStatusCodes` table, symbol → code reverse map (deprecated aliases), `StatusWithNoEntityBody`, and the insertion-ordered, key-down-casing `Headers`. | **Done** |
| Content negotiation & cookies | `QValues`, `BestQMatch`, `GetByteRanges`; `ParseCookiesHeader`, `MakeCookieHeader` / `MakeDeleteCookieHeader` and the `…Into` mutators. | **Done** |
| Request over an Env | Method predicates, `PathInfo` / `QueryString` / `GET` / `POST` / `Params` / `Cookies`, `ContentType` / `MediaType`, `Host` / `Port` / `Scheme` / `SSL` / `BaseURL` / `URL`, `XHR`, `IP` with trusted-proxy filter. | **Done** |
| Response & SPEC tuple | `NewResponse` / `NewResponseString` / `ResponseTuple`, `Write`, `Finish` / `ToA`, `SetStatus`, `SetCookie` / `DeleteCookie`, `Redirect`, status-class predicates. | **Done** |
| Body/Input seam | The single `Input` interface through which the host supplies the request body, memoised into the env like the gem. | **Done** |
| Differential oracle & coverage | Escape, query, status, cookie, media-type, byte-range and `Response#finish` checked byte-for-byte against `ruby` + the `rack` gem; 100% coverage, green across 6 arches and 3 OSes. | **Done** |

## Documented out-of-scope boundaries

These are **deliberate**, recorded so the module's surface is unambiguous:

- **No HTTP server.** `Rack::Handler`, the socket accept loop and TLS are the
  **host's** job. This library never touches the network; the request body comes
  in through the one explicit [`Input`](api.md#the-bodyinput-seam) seam.
- **No interpreter.** The library implements the deterministic compute; it never
  runs arbitrary Ruby (`Rack::Builder` DSL, middleware `call` chains). Anything
  that needs a live binding is the consumer's job — that is why `rbgo` binds this
  module rather than the reverse.
- **Reference is the `rack` gem (Rack 3.x, MRI).** Byte-for-byte conformance
  targets the reference gem's behaviour, pinned by the differential oracle.
- **Standalone & reusable.** The module has no dependency on the Ruby runtime;
  the dependency runs the other way.

See [Usage & API](api.md) for the surface and [Why pure Go](why.md) for the
deterministic/interpreter split.
