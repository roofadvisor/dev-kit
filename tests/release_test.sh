#!/usr/bin/env bash
# Release hygiene: the two version fields must agree, and the package must ship exactly what a
# consumer's gates need — kit/ and scripts/ to run, .claude-plugin/ for the one version-read path
# (`$KIT/../.claude-plugin/plugin.json`) — and nothing else. plugin.json said 2.1.0 while
# package.json said 2.0.0 for a whole release and nothing noticed (spec §3). And the plugin's own
# CI must run every harness verify.sh runs: it ran seven of eleven, and a harness that is green
# locally and absent in CI is the shape of failure this whole release is about.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (expected '$2', got '$3')"; fi }
# One reader for every field: a list prints comma-joined, a bool prints True/False, a missing key prints None.
field() { python3 -c 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2]); print(",".join(v) if isinstance(v,list) else v)' "$1" "$2"; }

check "package.json version equals plugin.json version"   "$(field "$KIT/.claude-plugin/plugin.json" version)" "$(field "$KIT/package.json" version)"
check "package name is @roofadvisor/dev-kit"              "@roofadvisor/dev-kit"        "$(field "$KIT/package.json" name)"
check "files is exactly kit, scripts, .claude-plugin"     "kit,scripts,.claude-plugin"  "$(field "$KIT/package.json" files)"
check "package stays private (no accidental npm publish)" "True"                        "$(field "$KIT/package.json" private)"
check "package-lock root name matches"                    "@roofadvisor/dev-kit"        "$(field "$KIT/package-lock.json" name)"

# The two harness lists, verbatim from their `for t in …; do` lines.
vlist=$(grep -oE '^for t in [a-z_ ]+; do' "$KIT/scripts/verify.sh" | sed -E 's/^for t in (.*); do/\1/')
clist=$(grep -oE 'for t in [a-z_ ]+; do' "$KIT/.github/workflows/gates.yml" | sed -E 's/for t in (.*); do/\1/')
check "the plugin's CI runs every harness verify.sh runs" "$vlist" "$clist"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
