// SPDX-License-Identifier: BSD-3-Clause
package main

import (
	"strconv"
	"strings"

	"github.com/go-ruby-rack/rack"
)

// serVal canonicalises a nested Rack value (nil / string / []any / *rack.Params
// / *rack.Headers) into a length-prefixed, fully unambiguous byte string, so the
// Go and Ruby drivers can be diffed byte-for-byte regardless of value content.
// The grammar (identical in ruby/rack.rb#ser):
//
//	nil     -> "N;"
//	string  -> "S" <bytelen> ":" <bytes> ";"
//	array   -> "A" <count>   ":" ser(e0) ser(e1) ... ";"
//	hash    -> "H" <count>   ":" ("K" <keylen> ":" <keybytes> ser(val)) ... ";"
//
// Length prefixes make the encoding independent of the bytes themselves, so
// multi-byte UTF-8 keys/values and empty strings all round-trip unambiguously.
func serVal(v any) string {
	var b strings.Builder
	writeVal(&b, v)
	return b.String()
}

func writeVal(b *strings.Builder, v any) {
	switch val := v.(type) {
	case nil:
		b.WriteString("N;")
	case string:
		b.WriteByte('S')
		b.WriteString(strconv.Itoa(len(val)))
		b.WriteByte(':')
		b.WriteString(val)
		b.WriteByte(';')
	case []any:
		b.WriteByte('A')
		b.WriteString(strconv.Itoa(len(val)))
		b.WriteByte(':')
		for _, e := range val {
			writeVal(b, e)
		}
		b.WriteByte(';')
	case []string:
		b.WriteByte('A')
		b.WriteString(strconv.Itoa(len(val)))
		b.WriteByte(':')
		for _, e := range val {
			writeVal(b, e)
		}
		b.WriteByte(';')
	case *rack.Params:
		writeHash(b, val.Keys(), func(k string) any { x, _ := val.Get(k); return x })
	case *rack.Headers:
		writeHash(b, val.Keys(), func(k string) any { return val.Get(k) })
	default:
		panic("serVal: unsupported type")
	}
}

func writeHash(b *strings.Builder, keys []string, get func(string) any) {
	b.WriteByte('H')
	b.WriteString(strconv.Itoa(len(keys)))
	b.WriteByte(':')
	for _, k := range keys {
		b.WriteByte('K')
		b.WriteString(strconv.Itoa(len(k)))
		b.WriteByte(':')
		b.WriteString(k)
		writeVal(b, get(k))
	}
	b.WriteByte(';')
}
