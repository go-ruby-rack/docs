// SPDX-License-Identifier: BSD-3-Clause
package main

import (
	"os"
	"strconv"

	"github.com/go-ruby-rack/rack"
)

// Fixed representative inputs, byte-identical to ruby/rack.rb.
const (
	// A realistic form value: spaces, reserved bytes ('&', '=', '%'), and
	// multi-byte UTF-8 (café, René, em-dash, cœur) so percent-encoding covers
	// >1-byte runes.
	urlInput = "Café René & Co. — 100% \"cœur\", a=1 b=2 (x/y) #frag"

	// An HTML fragment exercising all five Rack::Utils.escape_html characters
	// (&, <, >, ", ').
	htmlInput = "<a href=\"/u?id=42&t=1\">Tom & Jerry's \"Big\" <Adventure></a> 5 > 3 & 2 < 4"

	// A realistic flat query string: repeated (array) keys, a %-encoded value
	// with a multi-byte rune, a '+'-as-space value, and a valueless key.
	queryInput = "name=John+Doe&email=j%40x.com&tags[]=a&tags[]=b&tags[]=c&q=caf%C3%A9+%26+co&page=2&sort=desc&empty="

	// A nested query body: hash nesting, an array leaf, a two-level hash, an
	// empty-valued key and a bare key (nil).
	nestedInput = "user[name]=John+Doe&user[roles][]=admin&user[roles][]=ops&meta[a][b]=deep&flag=&bare"
)

// buildFlat is the ordered map fed to BuildQuery, mirroring the Ruby Hash in
// rack.rb (insertion order preserved).
func buildFlat() *rack.Params {
	p := rack.NewParams()
	p.Set("name", "John Doe")
	p.Set("email", "j@x.com")
	p.Set("tags", []any{"a", "b", "c"})
	p.Set("q", "café & co")
	p.Set("page", "2")
	return p
}

// buildNestedVal is the nested structure fed to BuildNestedQuery.
func buildNestedVal() *rack.Params {
	user := rack.NewParams()
	user.Set("name", "John Doe")
	user.Set("roles", []any{"admin", "ops"})
	p := rack.NewParams()
	p.Set("user", user)
	p.Set("items", []any{"1", "2"})
	p.Set("tag", "x")
	return p
}

// reqEnv is the fixed Rack environment for the Request op.
func reqEnv() rack.Env {
	return rack.Env{
		"REQUEST_METHOD":        "GET",
		"SCRIPT_NAME":           "/app",
		"PATH_INFO":             "/users/42",
		"QUERY_STRING":          "q=caf%C3%A9&page=2",
		"SERVER_NAME":           "example.com",
		"SERVER_PORT":           "443",
		"HTTP_HOST":             "example.com:443",
		"rack.url_scheme":       "https",
		"CONTENT_TYPE":          "text/html; charset=utf-8",
		"HTTP_X_REQUESTED_WITH": "XMLHttpRequest",
	}
}

// requestResult builds a Request and serialises a fixed ordered set of accessor
// outputs (all rendered as strings), matching ruby/rack.rb#request_result.
func requestResult() string {
	r := rack.NewRequest(reqEnv())
	out := rack.NewParams()
	out.Set("request_method", r.RequestMethod())
	out.Set("script_name", r.ScriptName())
	out.Set("path_info", r.PathInfo())
	out.Set("query_string", r.QueryString())
	out.Set("host", r.Host())
	out.Set("port", strconv.Itoa(r.Port()))
	out.Set("scheme", r.Scheme())
	out.Set("ssl", strconv.FormatBool(r.SSL()))
	out.Set("content_type", r.ContentType())
	out.Set("media_type", r.MediaType())
	out.Set("xhr", strconv.FormatBool(r.XHR()))
	out.Set("base_url", r.BaseURL())
	out.Set("path", r.Path())
	out.Set("fullpath", r.Fullpath())
	out.Set("url", r.URL())
	return serVal(out)
}

// responseResult builds a Response, finishes it, and serialises the resulting
// [status, headers, body] tuple, matching ruby/rack.rb#response_result.
func responseResult() string {
	h := rack.NewHeaders()
	h.Set("content-type", "text/plain")
	h.Set("x-custom", "alpha")
	r := rack.NewResponse(nil, 200, h)
	r.Write("Hello, ")
	r.Write("World!")
	status, headers, body := r.Finish()
	out := rack.NewParams()
	out.Set("status", strconv.Itoa(status))
	out.Set("headers", headers)
	out.Set("body", body)
	return serVal(out)
}

func main() {
	// esc is the escaped URL string, the hot input to the unescape op.
	esc := rack.Escape(urlInput)

	if len(os.Args) > 1 && os.Args[1] == "check" {
		u, _ := rack.Unescape(esc)
		pq, _ := rack.ParseQuery(queryInput, "")
		pnq, _ := rack.ParseNestedQuery(nestedInput, "&", rack.DefaultParamDepthLimit)
		bnq, _ := rack.BuildNestedQuery(buildNestedVal(), "")
		check("escape", rack.Escape(urlInput))
		check("unescape", u)
		check("escape_html", rack.EscapeHTML(htmlInput))
		check("parse_query", serVal(pq))
		check("build_query", rack.BuildQuery(buildFlat()))
		check("parse_nested_query", serVal(pnq))
		check("build_nested_query", bnq)
		check("request", requestResult())
		check("response", responseResult())
		return
	}

	bench("escape", 5000, func() { sink = rack.Escape(urlInput) })
	bench("unescape", 5000, func() { sink, _ = rack.Unescape(esc) })
	bench("escape_html", 5000, func() { sink = rack.EscapeHTML(htmlInput) })
	bench("parse_query", 2000, func() { sink, _ = rack.ParseQuery(queryInput, "") })
	bench("build_query", 2000, func() { sink = rack.BuildQuery(buildFlat()) })
	bench("parse_nested_query", 2000, func() {
		sink, _ = rack.ParseNestedQuery(nestedInput, "&", rack.DefaultParamDepthLimit)
	})
	bench("build_nested_query", 2000, func() { sink, _ = rack.BuildNestedQuery(buildNestedVal(), "") })
	bench("request", 2000, func() { sink = requestResult() })
	bench("response", 2000, func() { sink = responseResult() })
}
