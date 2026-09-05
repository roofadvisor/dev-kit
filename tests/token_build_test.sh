#!/usr/bin/env bash
# build_tokens.mjs — the unmapped-group report, and the composite types it used to drop.
#
# Why this harness exists: three roof-club systems each declared `font.line-height` where the
# builder reads `font.leading`, and every line-height was dropped from every build for weeks with
# no error and nothing obviously missing from the CSS. The builder had no tests at all. Every
# assertion below is red-then-green — the warning is seen to fire before it counts (G-01).
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
B="$KIT/kit/scripts/build_tokens.mjs"
pass=0; fail=0
check() { if [ "$2" -eq "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (expected exit $2, got $3)"; fi }
has()   { if printf '%s' "$2" | grep -qF -- "$3"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (missing: $3)"; fi }
hasnt() { if printf '%s' "$2" | grep -qF -- "$3"; then fail=$((fail+1)); echo "FAIL: $1 (unexpected: $3)"; else pass=$((pass+1)); fi }

# A minimal but realistic two-file system, the layout every roof-club system uses.
fixture() {
  local d; d="$(mktemp -d)"
  cat > "$d/colors.json" <<'JSON'
{ "primitive": { "ink": { "900": { "$type": "color", "$value": "#111111" } } },
  "semantic": {
    "surface": { "page": {"$type":"color","$value":"#ffffff"}, "card": {"$type":"color","$value":"#ffffff"}, "raised": {"$type":"color","$value":"#fafafa"} },
    "text": { "primary": {"$type":"color","$value":"{primitive.ink.900}"}, "secondary": {"$type":"color","$value":"#555555"},
              "tertiary": {"$type":"color","$value":"#666666"}, "link": {"$type":"color","$value":"#0645ad"}, "on-action": {"$type":"color","$value":"#ffffff"} },
    "action": { "primary": {"$type":"color","$value":"#0b5d3b"} },
    "border": { "strong": {"$type":"color","$value":"#767676"}, "default": {"$type":"color","$value":"#dddddd"} } } }
JSON
  cat > "$d/foundation.json" <<'JSON'
{ "font": { "family": { "body": {"$type":"fontFamily","$value":["Inter","sans-serif"]} },
            "size": { "md": {"$type":"dimension","$value":"14px"} },
            "leading": { "normal": {"$type":"number","$value":1.5} } },
  "space": { "1": {"$type":"dimension","$value":"4px"} } }
JSON
  printf '%s' "$d"
}

# ---------- the report ----------
D="$(fixture)"
out=$(node "$B" --in "$D" --out "$D/out.css" 2>&1); check "clean system exits 0" 0 $?
hasnt "clean system warns about nothing" "$out" "WARNING"
has   "clean system emits the leading token" "$(cat "$D/out.css")" "--leading-normal"

# red: the exact roof-club bug — the builder reads font.leading, not font.line-height
sed -i '' 's/"leading"/"line-height"/' "$D/foundation.json"
out=$(node "$B" --in "$D" --out "$D/out.css" 2>&1); check "unmapped group still builds (warn, not fail)" 0 $?
has "unmapped group is reported"        "$out" "produced no CSS variable"
has "unmapped group is named"           "$out" "font.line-height"
has "the near-miss sibling is suggested" "$out" "font.leading"
hasnt "the dropped var is genuinely absent" "$(cat "$D/out.css")" "--leading-"

# --strict is what a project's own token gate should run
node "$B" --in "$D" --out "$D/out.css" --strict >/dev/null 2>&1; check "--strict makes an unmapped group fatal" 1 $?
sed -i '' 's/"line-height"/"leading"/' "$D/foundation.json"
node "$B" --in "$D" --out "$D/out.css" --strict >/dev/null 2>&1; check "--strict passes a clean system" 0 $?
rm -rf "$D"

# ---------- the addressing forms ----------
# Claimed paths resolve either bare (font.size) or stem-namespaced (typography.fontSize)
# depending on the layout. Checking a leaf against only one form made EVERY directory-layout
# token read as unmapped — 62 false positives on the kit's own tokens.
D="$(fixture)"; rm "$D/foundation.json"
cat > "$D/typography.json" <<'JSON'
{ "fontFamily": { "body": {"$type":"fontFamily","$value":["Inter","sans-serif"]} },
  "fontSize": { "md": {"$type":"dimension","$value":"14px"} },
  "lineHeight": { "normal": {"$type":"number","$value":1.5} } }
JSON
cat > "$D/spacing.json" <<'JSON'
{ "scale": { "1": {"$type":"dimension","$value":"4px"} } }
JSON
out=$(node "$B" --in "$D" --out "$D/out.css" 2>&1)
hasnt "stem-namespaced layout is not falsely flagged" "$out" "WARNING"
has   "stem-namespaced layout still emits" "$(cat "$D/out.css")" "--leading-normal"
rm -rf "$D"

# ---------- composites that used to be dropped in silence ----------
D="$(mktemp -d)"
cat > "$D/colors.json" <<'JSON'
{ "semantic": { "surface": {"page":{"$type":"color","$value":"#fff"},"card":{"$type":"color","$value":"#fff"},"raised":{"$type":"color","$value":"#fafafa"}},
  "text": {"primary":{"$type":"color","$value":"#111"},"secondary":{"$type":"color","$value":"#555"},"tertiary":{"$type":"color","$value":"#666"},"link":{"$type":"color","$value":"#06c"},"on-action":{"$type":"color","$value":"#fff"}},
  "action": {"primary":{"$type":"color","$value":"#063"}},
  "border": {"strong":{"$type":"color","$value":"#767676"},"default":{"$type":"color","$value":"#ddd"}} } }
JSON
cat > "$D/borders.json" <<'JSON'
{ "width": { "thin": {"$type":"dimension","$value":"1px"} },
  "style": { "default": {"$type":"border","$value":{"width":"1px","style":"solid","color":"#dddddd"}} } }
JSON
cat > "$D/gradients.json" <<'JSON'
{ "brand": { "primary": {"$type":"gradient","$value":[{"color":"#4f46e5","position":0},{"color":"#7c3aed","position":1}]} } }
JSON
cat > "$D/shadows.json" <<'JSON'
{ "elevation": { "sm": {"$type":"shadow","$value":[{"offsetX":"0","offsetY":"1px","blur":"2px","spread":"0","color":"rgba(0,0,0,0.1)"}]} } }
JSON
css=$(node "$B" --in "$D" 2>/dev/null)
has "border width emits"                 "$css" "--border-width-thin: 1px"
has "border composite emits a shorthand"  "$css" "--border-default: 1px solid #dddddd"
has "gradient stops emit a linear-gradient" "$css" "linear-gradient(#4f46e5 0%, #7c3aed 100%)"
# A gradient stop array and a shadow layer array are both arrays of objects; `position` is what
# tells them apart, so prove the shadow path did not regress into a gradient.
has "shadow layers still emit as shadows" "$css" "--shadow-sm: 0 1px 2px 0 rgba(0,0,0,0.1)"
hasnt "shadow did not become a gradient"  "$css" "--shadow-sm: linear-gradient"
rm -rf "$D"

# ---------- B1: colour tiers are claimed by their FILE, not by bare name ----------
# 2.1.0 seeded `claimed` with bare 'primitive','semantic','component','dark', so a top-level
# `semantic` in ANY file read as covered — spacing.json's 30 semantic tokens hid behind it.
D="$(fixture)"
cat > "$D/layout.json" <<'JSON'
{ "semantic": { "gutter": { "md": {"$type":"dimension","$value":"24px"} } } }
JSON
out=$(node "$B" --in "$D" --out "$D/out.css" 2>&1)
has "B1: a non-colour file's top-level semantic group is reported" "$out" "layout.semantic"
rm -rf "$D"

# ---------- B2: spacing.semantic emits ----------
css=$(node "$B" --in "$KIT/kit/tokens" 2>/dev/null)
has "B2: --space-page-inline-padding emits"        "$css" "--space-page-inline-padding:"
has "B2: --space-stack-md emits"                   "$css" "--space-stack-md:"
has "B2: --space-component-button-padding-x emits" "$css" "--space-component-button-padding-x:"
node "$B" --in "$KIT/kit/tokens" --out /dev/null --strict >/dev/null 2>&1; check "B2: the kit's own tokens are --strict clean" 0 $?

# ---------- B3b: a ref resolves by its real path, never by dropping a first segment ----------
# `{nope.primitive.ink.900}` used to resolve: both resolvers stripped any first segment and
# retried — leaving `primitive.ink.900`, a real key — and validate_tokens then matched any key
# ENDING in the ref. That is how `{dataviz.…}` passed for a file called data-viz.json. The fake
# ref needs one segment MORE than the real path: `{nope.ink.900}` would strip to `ink.900`, which
# is not a key, and the test would pass before the fix for the wrong reason.
D="$(fixture)"
python3 - "$D/colors.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["semantic"]["text"]["primary"]["$value"] = "{nope.primitive.ink.900}"
json.dump(d, open(p, "w"))
PY
python3 "$KIT/kit/scripts/validate_tokens.py" "$D" >/dev/null 2>&1; check "B3b: validate_tokens rejects a ref through a namespace that is not a file" 1 $?
css=$(node "$B" --in "$D" 2>/dev/null)
hasnt "B3b: the builder does not emit a value reached through a fake namespace" "$css" "--color-text-primary:"
rm -rf "$D"

# ---------- B3: the typo the rule now rejects, fixed at the source ----------
python3 "$KIT/kit/scripts/validate_tokens.py" "$KIT/kit/tokens" >/dev/null 2>&1; check "B3: the kit's own tokens resolve" 0 $?
css=$(node "$B" --in "$KIT/kit/tokens" 2>/dev/null)
has "B3: --color-chart-positive emits from the corrected ref" "$css" "--color-chart-positive:"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
