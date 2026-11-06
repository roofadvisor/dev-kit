#!/usr/bin/env bash
# A colour gate must not measure a colour that is still fading.
#
# Why this harness exists: axe_audit.mjs --dark flipped data-theme and ran axe at once. A
# component with `transition: background 120ms` then had its NEW text colour on its OLD
# background for those 120ms, and axe reported a contrast failure that depended on how long
# the axe-core script took to load. roof-club's operator harness failed about 1 run in 12 with
# no code change (2026-11-02 to 2026-11-06). measure_render.mjs and verify_states.mjs already
# switched transitions off before the flip; axe_audit.mjs and lint_intent.mjs did not.
#
# Two parts. The static rule always runs. The rendered case runs when a browser and axe-core
# can be loaded, and says so when they cannot: the plugin's CI installs no browser.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
S="$KIT/kit/scripts"
pass=0; fail=0
ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }

# ---------- static: kill transitions before the theme flip ----------
# Derived from the scripts, not a kept list: every gate that flips data-theme at run time AND
# reads a colour (a computed colour, or axe) is held to the rule. A gate that flips the theme
# and reads only geometry or focus is not.
FLIP="setAttribute('data-theme'"
KILL='transition:none!important'
READS='backgroundColor|\.color\b|axe\.run'
found=0
for f in "$S"/*.mjs; do
  grep -qF "$FLIP" "$f" || continue
  grep -qE "$READS" "$f" || continue
  found=$((found+1))
  flip_line=$(grep -nF "$FLIP" "$f" | head -1 | cut -d: -f1)
  kill_line=$(grep -nF "$KILL" "$f" | head -1 | cut -d: -f1)
  if [ -n "$kill_line" ] && [ "$kill_line" -lt "$flip_line" ]; then ok
  else bad "$(basename "$f") flips data-theme (line $flip_line) and reads a colour without switching transitions off first"; fi
done
# An empty set would pass without checking anything (a renamed attribute, a moved folder).
if [ "$found" -ge 4 ]; then ok; else bad "found only $found theme-flipping colour gates under kit/scripts; expected at least 4"; fi

# ---------- rendered: the fixture fails without the guard and passes with it ----------
T="$(mktemp -d)"
cat > "$T/fade.html" <<'HTML'
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>fade</title>
<style>
  body{margin:0}
  main{background:#ffffff}
  p{color:#111111;background:#ffffff;transition:background 30s linear}
  [data-theme="dark"] main{background:#111111}
  [data-theme="dark"] h1{color:#eeeeee}
  [data-theme="dark"] p{color:#eeeeee;background:#111111}
</style></head><body><main><h1>Fade</h1><p>Light text lands at once; the background takes 30 seconds.</p></main></body></html>
HTML
# The same script with the guard line removed, beside its own loader, so the red case is the
# shipped code minus the fix and nothing else.
mkdir -p "$T/unguarded"
cp "$S/_playwright.mjs" "$T/unguarded/"
grep -vF "$KILL" "$S/axe_audit.mjs" > "$T/unguarded/axe_audit.mjs"

# DS_INVOKE_CWD lets a caller point at a project that has Playwright installed.
out=$(cd "$KIT" && node "$S/axe_audit.mjs" "$T/fade.html" --dark 2>&1); rc=$?
if printf '%s' "$out" | grep -q 'SKIPPED'; then
  echo "NOTE: no browser or no axe-core here, so the rendered case did not run. The static rule above still counts."
else
  if [ "$rc" -eq 0 ]; then ok; else bad "guarded axe_audit --dark failed on a fading background: $(printf '%s' "$out" | tail -3 | tr '\n' ' ')"; fi
  (cd "$KIT" && node "$T/unguarded/axe_audit.mjs" "$T/fade.html" --dark >/dev/null 2>&1); urc=$?
  if [ "$urc" -eq 1 ]; then ok; else bad "the unguarded copy passed, so this fixture does not prove the guard (exit $urc)"; fi
  # Light mode flips nothing and must pass either way: the fixture is sound at rest.
  (cd "$KIT" && node "$S/axe_audit.mjs" "$T/fade.html" >/dev/null 2>&1); lrc=$?
  if [ "$lrc" -eq 0 ]; then ok; else bad "the fixture fails in light mode, so it is not a transition test (exit $lrc)"; fi
fi
rm -rf "$T"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
