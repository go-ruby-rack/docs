# Usage & API

The public API lives at the module root (`github.com/go-ruby-rack/rack`). It is
**Ruby-shaped but Go-idiomatic**: the names mirror the `rack` gem's
(`Rack::Utils.escape` → `Escape`, `Rack::Request#GET` → `Request.GET`,
`Rack::Response#finish` → `Response.Finish`), while the surface follows Go
conventions — value types, explicit errors, an explicit body seam, no global
state.

!!! success "Status: implemented"
    The library is built and importable as `github.com/go-ruby-rack/rack`, bound
    into `rbgo` as the Rack backend; see [Roadmap](roadmap.md).

## Install

```sh
go get github.com/go-ruby-rack/rack
```

## Worked example

```go
package main

import (
	"fmt"

	"github.com/go-ruby-rack/rack"
)

func main() {
	// Parse a nested query string into structural types.
	p, _ := rack.ParseNestedQuery("user[name]=ada&user[langs][]=go", "&",
		rack.DefaultParamDepthLimit)
	fmt.Println(p.Get("user")) // *rack.Params {"name"=>"ada", "langs"=>["go"]}

	// Shape a request over a Rack env.
	req := rack.NewRequest(rack.Env{
		rack.RequestMethod: "GET",
		rack.PathInfo:      "/search",
		rack.QueryString:   "q=hello+world",
		rack.HTTPHost:      "example.com",
		rack.RackURLScheme: "https",
	})
	fmt.Println(req.URL()) // https://example.com/search?q=hello+world
	get, _ := req.GET()
	fmt.Println(get.Get("q")) // "hello world"

	// Build a response and emit the SPEC tuple.
	res := rack.NewResponseString("Hello", 200, nil)
	res.SetContentType("text/plain")
	status, headers, body := res.Finish()
	fmt.Println(status, headers.Get("content-length"), body)
	// 200 5 [Hello]
}
```

## Utils — query, escaping, status, negotiation, cookies

```go
// query parsing / building
func ParseQuery(qs, sep string) (*Params, error)
func ParseNestedQuery(qs, sep string, depthLimit int) (*Params, error) // foo[bar], foo[], x[][a]
func BuildQuery(p *Params) string
func BuildNestedQuery(value any, prefix string) (string, error)

// escaping — byte-identical to MRI (unreserved set, upper-case hex)
func Escape(s string) string;        func Unescape(s string) (string, error)
func EscapePath(s string) string;    func UnescapePath(s string) (string, error)
func EscapeHTML(s string) string;    func UnescapeHTML(s string) string

// status codes
func SymbolToStatusCode(sym string) (code int, ok bool)
func StatusWithNoEntityBody(status int) bool

// content negotiation & byte ranges
func QValues(header string) []QValue
func BestQMatch(header string, available []string) string
func GetByteRanges(httpRange string, size, maxRanges int) ([]ByteRange, bool)

// cookies
func ParseCookiesHeader(value string) *Params
func MakeCookieHeader(key string, c CookieValue) (string, error)
func MakeDeleteCookieHeader(key string, c CookieValue) (string, error)
func SetCookieHeaderInto(h *Headers, key string, c CookieValue) error
func DeleteCookieHeaderInto(h *Headers, key string, c CookieValue) error

// media type
func MediaTypeOf(contentType string) string
func MediaTypeParams(contentType string) *Params

// trusted-proxy predicate (used by Request.IP)
func TrustedProxy(ip string) bool
```

`ParseNestedQuery` expands `foo[bar]` / `foo[]` / `x[][a]` bracket nesting
exactly like the gem — including the array-of-hash vs nested-array subtleties and
the `ParameterTypeError` / `ParamsTooDeepError` conflicts — and `BuildQuery` /
`BuildNestedQuery` invert it. Pass `rack.DefaultParamDepthLimit` for the standard
depth guard.

## Request over an Env

```go
func NewRequest(env Env) *Request

// method predicates
func (r *Request) IsGet() bool;  func (r *Request) IsPost() bool
func (r *Request) IsPut() bool;  func (r *Request) IsDelete() bool
func (r *Request) IsHead() bool; func (r *Request) IsPatch() bool
func (r *Request) IsOptions() bool; func (r *Request) IsTrace() bool // + Link/Unlink

// path, query, params, cookies
func (r *Request) PathInfo() string;    func (r *Request) QueryString() string
func (r *Request) Fullpath() string;    func (r *Request) ScriptName() string
func (r *Request) GET() (*Params, error);   func (r *Request) POST() (*Params, error)
func (r *Request) Params() (*Params, error); func (r *Request) Cookies() *Params

// content type / media type
func (r *Request) ContentType() string;  func (r *Request) ContentCharset() string
func (r *Request) MediaType() string;    func (r *Request) MediaTypeParams() *Params

// host / port / scheme / URLs
func (r *Request) Host() string;   func (r *Request) Hostname() string
func (r *Request) Port() int;      func (r *Request) HostWithPort() string
func (r *Request) Scheme() string; func (r *Request) SSL() bool
func (r *Request) BaseURL() string; func (r *Request) URL() string
func (r *Request) XHR() bool;      func (r *Request) IP() string // trusted-proxy filter

// header accessors
func (r *Request) GetHeader(name string) string; func (r *Request) HasHeader(name string) bool
func (r *Request) SetHeader(name, value string); func (r *Request) DeleteHeader(name string)
```

`Request.POST` / `Request.Params` read the body only for form-data content types,
parse it with `ParseNestedQuery`, and memoise into the env exactly like the gem.

## Response & the SPEC tuple

```go
func NewResponse(body []string, status int, headers *Headers) *Response
func NewResponseString(body string, status int, headers *Headers) *Response
func ResponseTuple(status int, headers *Headers, body []string) *Response

func (r *Response) Write(s string);          func (r *Response) SetStatus(code int)
func (r *Response) Finish() (int, *Headers, []string) // the [status, headers, body] tuple
func (r *Response) ToA() (int, *Headers, []string)    // alias of Finish

func (r *Response) SetContentType(ct string)
func (r *Response) SetCookie(key string, c CookieValue) error
func (r *Response) DeleteCookie(key string, c CookieValue) error
func (r *Response) Redirect(target string, status int)

// status-class predicates
func (r *Response) Successful() bool; func (r *Response) Redirection() bool
func (r *Response) ClientError() bool; func (r *Response) ServerError() bool
func (r *Response) NotFound() bool // ... OK/Created/BadRequest/Forbidden/… helpers
```

## Value model — Headers & Params

Parsed parameters and cookies are built from a small, fixed set of Go types — the
analogue of the Ruby `Hash`/`Array`/`String`/`nil` graph the gem returns:

| Ruby             | Go                       |
| ---------------- | ------------------------ |
| `Hash` (ordered) | `*rack.Params`           |
| `Array`          | `[]any`                  |
| `String`         | `string`                 |
| `nil`            | `nil`                    |
| response headers | `*rack.Headers` (ordered, down-cased keys) |

`*Params` preserves insertion order (like Ruby's `Hash`), so key order
round-trips through `BuildQuery` / `BuildNestedQuery`. Both `*Params` and
`*Headers` share the same small ordered-map surface:

```go
func (p *Params) Get(key string) any; func (p *Params) Has(key string) bool
func (p *Params) Set(key string, v any); func (p *Params) Delete(key string)
func (p *Params) Keys() []string; func (p *Params) Len() int
func (p *Params) Each(fn func(key string, v any)); func (p *Params) ToMap() map[string]any

func (h *Headers) Get(key string) string; func (h *Headers) GetOK(key string) (string, bool)
func (h *Headers) Set(key, value string); func (h *Headers) Delete(key string)
func (h *Headers) Keys() []string; func (h *Headers) Each(fn func(key, value string))
```

`Headers` mirrors `Rack::Headers`: insertion-ordered, keys down-cased on the way
in, matching Rack 3.x's lower-case-header rule.

## The body/input seam

Reading the request body is the one place this library defers to the host. A
`Request` reads `env["rack.input"]` through the small `Input` interface:

```go
type Input interface {
	// Read returns up to n bytes, or all remaining bytes when n < 0, and
	// nil at EOF — the subset of Ruby's IO contract Rack relies on.
	Read(n int) ([]byte, error)
}
```

The host (e.g. `rbgo`) supplies the `Input` over whatever socket or buffer it
has, so the package stays free of any network or runtime dependency. The HTTP
server itself — `Rack::Handler`, the accept loop, TLS — is out of scope by
design.

## MRI conformance

A **differential oracle** runs every escaping, query-parse, status, cookie,
media-type, byte-range and `Response#finish` case through both the system `ruby`
with the `rack` gem and this library, and compares them **byte-for-byte**. The
oracle scripts `$stdout.binmode` so Windows text-mode never pollutes the bytes,
and skip themselves where `ruby` or the gem is absent — so the qemu cross-arch and
Windows lanes still validate the library from the deterministic tests alone.
