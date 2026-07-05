#!/usr/bin/env bash
#
# Copyright (c) the go-ruby-rack/rack authors
# SPDX-License-Identifier: BSD-3-Clause
#
# Library-level cross-runtime benchmark runner.
#
# Runs the SAME workload through (a) the pure-Go go-ruby-rack/rack library
# (benchmarks/go) and (b) each available reference Ruby runtime
# (benchmarks/ruby/rack.rb), then prints one Markdown table per sub-benchmark:
# ns/op and the ratio vs MRI.
#
# Usage:  bash benchmarks/run.sh
# Env:    OUTER (timed passes, default 25), WARM (untimed passes, default 3),
#         RUBY / JRUBY / TRUFFLERUBY (override runtime binaries).
set -u
cd "$(dirname "$0")"

export GOWORK=off

RUBY=${RUBY:-ruby}
JRUBY=${JRUBY:-jruby}
TRUFFLERUBY=${TRUFFLERUBY:-truffleruby}

RB=ruby/rack.rb
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

run() { # <runtime-label> <cmd...>
  local label=$1; shift
  command -v "$1" >/dev/null 2>&1 || { echo "  ($label: $1 not found — skipped)" >&2; return; }
  echo "  $label ..." >&2
  "$@" 2>/dev/null | awk -v r="$label" '$1=="RESULT"{printf "%s\t%s\t%s\n", r, $2, $3}' >> "$TMP"
}

echo "== go-ruby-rack library-level benchmark ==" >&2

# Parity gate: the Go library's output must be byte-identical to MRI (the oracle)
# for every op before any timing is trusted. Both drivers emit `CHECK <label>
# <hex>` lines in "check" mode; we diff them and abort on any mismatch.
echo "  verifying go output == MRI ..." >&2
GO_CHECK=$( cd go && go run . check 2>/dev/null | grep '^CHECK' | sort )
MRI_CHECK=$( "$RUBY" "$RB" check 2>/dev/null | grep '^CHECK' | sort )
if [ "$GO_CHECK" != "$MRI_CHECK" ]; then
  echo "  PARITY FAILURE — go output differs from MRI:" >&2
  diff <(printf '%s\n' "$MRI_CHECK") <(printf '%s\n' "$GO_CHECK") >&2
  exit 1
fi
echo "  parity OK (go == MRI on all ops)" >&2

echo "  go ..." >&2
( cd go && command -v go >/dev/null 2>&1 && go run . 2>/dev/null ) \
  | awk '$1=="RESULT"{printf "go\t%s\t%s\n", $2, $3}' >> "$TMP"
run "mri"         "$RUBY"                "$RB"
run "mri-yjit"    "$RUBY" --yjit        "$RB"
run "jruby"       "$JRUBY"              "$RB"
run "truffleruby" "$TRUFFLERUBY"        "$RB"

echo >&2
# Emit one Markdown table per sub-benchmark (label), runtimes as rows. Labels are
# printed in the workload's natural order (as first seen in the go output).
awk -F'\t' '
  { key=$2; rt=$1; ns=$3
    if (!(key in seen)) { seen[key]=1; ord_lab[++nl]=key }
    val[rt SUBSEP key]=ns; rts[rt]=1 }
  END {
    order="go mri mri-yjit jruby truffleruby"
    n=split(order, ord, " ")
    for (i=1;i<=nl;i++){
      k=ord_lab[i]
      printf "\n#### %s\n\n", k
      print  "| Runtime | ns/op | vs MRI |"
      print  "| --- | ---: | ---: |"
      base=val["mri" SUBSEP k]
      for (o=1;o<=n;o++){
        rt=ord[o]; v=val[rt SUBSEP k]
        if (v=="") continue
        ratio=(base!=""&&base+0>0)? sprintf("%.2f×", v/base) : "—"
        name=rt
        if (rt=="go") name="**go-ruby (pure Go)**"
        else if (rt=="mri") name="MRI"
        else if (rt=="mri-yjit") name="MRI + YJIT"
        else if (rt=="jruby") name="JRuby"
        else if (rt=="truffleruby") name="TruffleRuby"
        printf "| %s | %s | %s |\n", name, v, ratio
      }
    }
  }
' "$TMP"
