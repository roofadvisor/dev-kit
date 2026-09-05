#!/usr/bin/env bash
# The registry gates run from node_modules — proven in a synthetic consumer, not in this repo,
# where each scanner would find its own in-repo twin (it excludes itself by __file__, and the
# twin is a different path). Three things must hold (spec §3, §5): silent on a clean tree with
# no finding inside node_modules; a real violation still caught; and a forgotten
# .github/scripts/ copy caught by the assertion gates.yml carries — the scanners skip
# dot-directories, so nothing else would notice it.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
check() { if [ "$2" -eq "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (expected exit $2, got $3)"; fi }
has()   { if printf '%s' "$2" | grep -qF -- "$3"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (missing: $3)"; fi }
hasnt() { if printf '%s' "$2" | grep -qF -- "$3"; then fail=$((fail+1)); echo "FAIL: $1 (unexpected: $3)"; else pass=$((pass+1)); fi }

C="$(mktemp -d)"; ( cd "$C" && git init -q )
NM="$C/node_modules/@roofadvisor/dev-kit"; mkdir -p "$NM" "$C/.claude/rules" "$C/src"
cp -R "$KIT/scripts" "$NM/scripts"                                   # what `files` ships
printf -- '---\nid: core\nalways_apply: true\ntitle: Core\n---\n# Core\n' > "$C/.claude/rules/core.md"
printf 'export const x = 1;\n' > "$C/src/clean.ts"
run() { ( cd "$C" && python3 "node_modules/@roofadvisor/dev-kit/scripts/$1" 2>&1 ); }

for g in check_guess_lists check_statelessness check_log_hygiene; do
  out=$(run "$g.py"); code=$?
  check "$g: silent on a clean consumer" 0 "$code"
  hasnt "$g: never reports into node_modules" "$out" "node_modules"
done
( cd "$C" && python3 node_modules/@roofadvisor/dev-kit/scripts/render_instructions.py --rules-dir .claude/rules --write >/dev/null 2>&1 \
          && python3 node_modules/@roofadvisor/dev-kit/scripts/render_instructions.py --rules-dir .claude/rules --check >/dev/null 2>&1 )
check "render_instructions: relocated, takes --rules-dir, needs no _common" 0 $?

printf 'console.log("user", user.password);\n' > "$C/src/leak.ts"
out=$(run check_log_hygiene.py); code=$?
check "a planted credential log is caught from the relocated copy" 1 "$code"
has "the finding names the file" "$out" "src/leak.ts"
rm "$C/src/leak.ts"

# The assertion templates/github/gates.yml carries, verbatim.
guard() { ( cd "$C" && if ls .github/scripts/check_*.py >/dev/null 2>&1; then exit 1; else exit 0; fi ); }
guard; check "no vendored copies: the assertion passes on a clean consumer" 0 $?
mkdir -p "$C/.github/scripts" && cp "$NM/scripts/check_log_hygiene.py" "$C/.github/scripts/"
out=$(run check_log_hygiene.py); check "the scanners do NOT see .github/ — which is why the assertion exists" 0 $?
guard; check "a forgotten .github/scripts/ copy fails the assertion" 1 $?
grep -qF 'ls .github/scripts/check_*.py' "$KIT/templates/github/gates.yml"; check "gates.yml template carries the same assertion" 0 $?
grep -qF 'python "node_modules/@roofadvisor/dev-kit/scripts/$1"' "$KIT/templates/github/gates.yml"; check "gates.yml template runs the gates from node_modules" 0 $?
rm -rf "$C"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
