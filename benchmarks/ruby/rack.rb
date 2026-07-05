# frozen_string_literal: true
# SPDX-License-Identifier: BSD-3-Clause
#
# Cross-runtime workload for Rack's pure-compute surface (Rack::Utils, Request,
# Response), byte-identical to the pure-Go go-ruby-rack/rack driver in ../go. Run
# with no args to print RESULT ns/op lines; run with "check" to print
# CHECK <label> <hex> lines for a byte-for-byte parity diff against the Go driver.

require "rack"
require "rack/utils"
require_relative "_harness"

U = Rack::Utils

# Fixed representative inputs, byte-identical to go/main.go.
URL_INPUT    = "Café René & Co. — 100% \"cœur\", a=1 b=2 (x/y) #frag"
HTML_INPUT   = "<a href=\"/u?id=42&t=1\">Tom & Jerry's \"Big\" <Adventure></a> 5 > 3 & 2 < 4"
QUERY_INPUT  = "name=John+Doe&email=j%40x.com&tags[]=a&tags[]=b&tags[]=c&q=caf%C3%A9+%26+co&page=2&sort=desc&empty="
NESTED_INPUT = "user[name]=John+Doe&user[roles][]=admin&user[roles][]=ops&meta[a][b]=deep&flag=&bare"

ESC_URL = U.escape(URL_INPUT)

# The ordered Hash fed to build_query, mirroring go/main.go#buildFlat.
BUILD_FLAT = { "name" => "John Doe", "email" => "j@x.com",
               "tags" => %w[a b c], "q" => "café & co", "page" => "2" }

# The nested structure fed to build_nested_query, mirroring buildNestedVal.
BUILD_NESTED = { "user" => { "name" => "John Doe", "roles" => %w[admin ops] },
                 "items" => %w[1 2], "tag" => "x" }

# The fixed Rack environment for the Request op, mirroring go/main.go#reqEnv.
def req_env
  {
    "REQUEST_METHOD"        => "GET",
    "SCRIPT_NAME"           => "/app",
    "PATH_INFO"             => "/users/42",
    "QUERY_STRING"          => "q=caf%C3%A9&page=2",
    "SERVER_NAME"           => "example.com",
    "SERVER_PORT"           => "443",
    "HTTP_HOST"             => "example.com:443",
    "rack.url_scheme"       => "https",
    "CONTENT_TYPE"          => "text/html; charset=utf-8",
    "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
  }
end

# ser canonicalises a nested Rack value (nil / String / Array / Hash) into a
# length-prefixed byte string, identical to go/serialize.go#serVal. See that file
# for the grammar. Strings are appended as raw bytes so multi-byte UTF-8 keys and
# values round-trip unambiguously.
def ser(v)
  case v
  when nil
    +"N;"
  when String
    b = v.b
    (+"S") << b.bytesize.to_s << ":" << b << ";"
  when Array
    out = (+"A") << v.size.to_s << ":"
    v.each { |e| out << ser(e) }
    out << ";"
  when Hash
    out = (+"H") << v.size.to_s << ":"
    v.each do |k, val|
      kb = k.to_s.b
      out << "K" << kb.bytesize.to_s << ":" << kb << ser(val)
    end
    out << ";"
  else
    raise "ser: unsupported #{v.class}"
  end
end

# request_result builds a Request and serialises a fixed ordered set of accessor
# outputs (all rendered as strings), matching go/main.go#requestResult.
def request_result
  r = Rack::Request.new(req_env)
  out = {
    "request_method" => r.request_method,
    "script_name"    => r.script_name,
    "path_info"      => r.path_info,
    "query_string"   => r.query_string,
    "host"           => r.host,
    "port"           => r.port.to_s,
    "scheme"         => r.scheme,
    "ssl"            => r.ssl?.to_s,
    "content_type"   => r.content_type,
    "media_type"     => r.media_type,
    "xhr"            => r.xhr?.to_s,
    "base_url"       => r.base_url,
    "path"           => r.path,
    "fullpath"       => r.fullpath,
    "url"            => r.url,
  }
  ser(out)
end

# response_result builds a Response, finishes it, and serialises the resulting
# [status, headers, body] tuple, matching go/main.go#responseResult.
def response_result
  resp = Rack::Response.new(nil, 200, { "content-type" => "text/plain", "x-custom" => "alpha" })
  resp.write("Hello, ")
  resp.write("World!")
  status, headers, body = resp.finish
  parts = []
  body.each { |p| parts << p }
  ser({ "status" => status.to_s, "headers" => headers.to_h, "body" => parts })
end

if ARGV[0] == "check"
  check("escape",             U.escape(URL_INPUT))
  check("unescape",           U.unescape(ESC_URL))
  check("escape_html",        U.escape_html(HTML_INPUT))
  check("parse_query",        ser(U.parse_query(QUERY_INPUT)))
  check("build_query",        U.build_query(BUILD_FLAT))
  check("parse_nested_query", ser(U.parse_nested_query(NESTED_INPUT)))
  check("build_nested_query", U.build_nested_query(BUILD_NESTED))
  check("request",            request_result)
  check("response",           response_result)
  exit
end

bench("escape", 5000)              { U.escape(URL_INPUT) }
bench("unescape", 5000)            { U.unescape(ESC_URL) }
bench("escape_html", 5000)         { U.escape_html(HTML_INPUT) }
bench("parse_query", 2000)         { U.parse_query(QUERY_INPUT) }
bench("build_query", 2000)         { U.build_query(BUILD_FLAT) }
bench("parse_nested_query", 2000)  { U.parse_nested_query(NESTED_INPUT) }
bench("build_nested_query", 2000)  { U.build_nested_query(BUILD_NESTED) }
bench("request", 2000)             { request_result }
bench("response", 2000)            { response_result }
