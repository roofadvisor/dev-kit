#!/usr/bin/env bash
# Rule 0 — canonical home enforcement.
#
# Blocks creating a NEW file in a category that already has a canonical home,
# until the existing one has been named. This is the mechanical fix for the
# "twenty iterations, twenty near-duplicate files" pattern: reportV2.ts,
# report-final.ts, reportNew.ts accumulating because each session created rather
# than found.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_parse.sh"
hook_opted_in || exit 0

input=$(cat)
path=$(hook_field "$input" "file_path")
if [ -z "$path" ] && [ -n "$input" ]; then
  log_deny "G-03" "no extractable path from tool input (rule-zero)"
  echo "BLOCKED: rule-zero.sh could not extract a file path from the tool input." >&2
  echo "Install jq or python3, or fix the hook/matcher. Refusing to allow unverified file creation." >&2
  exit 2
fi
[ -z "$path" ] && exit 0
[ -e "$path" ] && exit 0          # editing an existing file is always fine

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
base=$(basename "$path")
dir=$(dirname "$path")
stem="${base%.*}"
ext="${base##*.}"

# Strip common iteration suffixes to find the concept this file is a variant of.
concept=$(printf '%s' "$stem" \
  | sed -E 's/([-_.]?(v[0-9]+|[0-9]+|new|old|final|copy|updated|fixed|temp|tmp|draft|rev[0-9]*|bak|backup|alt|2))+$//I' \
  | sed -E 's/^(new|old|final|copy|updated|fixed|temp|tmp|draft)[-_.]//I')

[ "$concept" = "$stem" ] && [ "${#concept}" -ge 3 ] && concept="$stem"
[ -z "$concept" ] && exit 0

# Look for an existing file expressing the same concept. In this directory, always: a
# second file of one concept beside the first is the case this rule exists for.
matches=$(find "$dir" -maxdepth 1 -type f -iname "*${concept}*.${ext}" 2>/dev/null | head -5)

# Across the repo, only for a VARIANT — a name that carried an iteration suffix or prefix
# (reportV2, report-final, new-report), which is evidence the author meant "another one of
# those". A plain name repeated in a new directory is how frameworks are laid out: route.ts,
# page.tsx, README.md and index.ts are one per directory by convention. This fallback used to
# run for every name whenever the target directory held no match — which is always, for a new
# directory — so it judged the first file of its kind in a fresh folder a duplicate of every
# same-named file anywhere, and no new Next.js route or page could be written (2.2.2). The
# evidence is the suffix, not the name, which is the same two-signal shape C-01 and C-03 use.
if [ -z "$matches" ] && [ "$concept" != "$stem" ]; then
  matches=$(git -C "$root" ls-files "*${concept}*.${ext}" 2>/dev/null | head -5)
fi

# A spec and its plan share a stem by convention — writing-plans puts them at
# docs/superpowers/specs/<x>-design.md and docs/superpowers/plans/<x>.md. That is two
# artifacts with two owners, not a variant, and the first plan written under this hook was
# blocked by its own spec (2.1.1). Drop a match that is the target's spec; everything else —
# including a -v2 of the plan once the plan exists — still blocks.
kept=""
while IFS= read -r m; do
  [ -n "$m" ] || continue
  case "$(basename "$m")" in
    "${concept}-design.${ext}"|"${concept}-spec.${ext}") continue ;;
  esac
  kept="${kept}${m}"$'\n'
done <<< "$matches"
matches="${kept%$'\n'}"

if [ -n "$matches" ]; then
  log_deny "C-05" "$path"
  {
    echo "BLOCKED by Rule 0 — a canonical home may already exist for '${concept}'."
    echo "Existing:"
    printf '%s\n' "$matches" | sed 's/^/  /'
    echo
    echo "Before creating '${base}', do one of:"
    echo "  1. Edit the existing file instead (usually correct)."
    echo "  2. If it is a second artifact, not a variant, name it for what it owns — a"
    echo "     name sharing this stem will keep being blocked. (One pair is sanctioned:"
    echo "     a plan beside its spec — plans/<x>.md with specs/<x>-design.md.)"
    echo "  3. If the existing file is dead, delete it in this same change."
    echo
    echo "Do not create a variant alongside it. That is how a codebase ends up with"
    echo "reportV2, report-final, and reportNew all half-true."
  } >&2
  exit 2
fi
exit 0
