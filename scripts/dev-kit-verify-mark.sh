#!/usr/bin/env bash
# dev-kit-verify-mark — runs the project's verify and, only if it exits 0, writes the
# marker hooks/done-check.sh reads (.claude/.last-verify at the repo root).
#
#   bash scripts/dev-kit-verify-mark.sh [--as full|fast] -- <command> [args...]
#
# Why it exists: hooks/verify-record.sh sees only a verify run through Claude's Bash
# tool, in the foreground, and that tool stops at 10 minutes. GHL-MCP's `npm run
# verify` takes ~21 minutes (1,241 s measured 2026-11-22), so no session there could
# meet done-check honestly, and a run in a terminal tab was never recorded. Wrapped by
# this script, the run writes its own marker wherever it runs: terminal tab, Bash tool,
# background task.
#
# What keeps it strict:
#  - The marker is written only after the command exits 0, and this script exits with
#    the command's own status. The one exception is loud: a pass whose marker cannot be
#    written exits 70, as does a start stamp that cannot be made.
#  - The marker's mtime is the run's START, not its end. done-check blocks when a source
#    file is newer than the marker, so a file edited while a 20-minute run was going is
#    still newer than the marker and still blocks.
#  - A run that finishes non-zero deletes the marker: the last verify of this tree
#    failed, so no earlier pass speaks for it. An interrupt (Ctrl-C, TERM) is not a
#    finished run and leaves the marker as it was.
#  - --as names which verify ran (full, or the project's declared fast check;
#    .claude/verify.json). The marker records it with the command, and done-check
#    names it when it blocks.
#
# Self-contained on purpose, so a project can vendor it as one file or call it from
# node_modules/@roofadvisor/dev-kit/scripts/ when it pins the kit. Needs git, bash and
# touch -r; no python3. Writes nothing under CI (CI set): a marker there has no reader.
set -uo pipefail

me=dev-kit-verify-mark
usage() {
  echo "usage: $me [--as full|fast] -- <verify command> [args...]" >&2
  exit 64
}

label=full
while [ $# -gt 0 ]; do
  case "$1" in
    --as) [ $# -ge 2 ] || usage; label=$2; shift 2 ;;
    --as=*) label=${1#--as=}; shift ;;
    --) shift; break ;;
    *) usage ;;
  esac
done
[ $# -gt 0 ] || usage
case "$label" in full|fast) ;; *) echo "$me: --as must be full or fast, not '$label'" >&2; exit 64 ;; esac

root=""
if [ -z "${CI:-}" ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null) || root=""
  [ -n "$root" ] || echo "$me: not inside a git repository; running without a marker." >&2
fi

stamp=""
if [ -n "$root" ]; then
  stamp=$(mktemp "${TMPDIR:-/tmp}/$me.XXXXXX") || { echo "$me: cannot create a start stamp; refusing to run without one." >&2; exit 70; }
fi
started=$(date -u +%Y-%m-%dT%H:%M:%SZ)
trap '[ -n "$stamp" ] && rm -f "$stamp"' EXIT
# Without these traps bash would still exit on the signal, but say so plainly: an
# interrupted run writes nothing.
trap 'echo "$me: interrupted; no marker written." >&2; exit 130' INT
trap 'echo "$me: terminated; no marker written." >&2; exit 143' TERM

"$@"
status=$?

[ -n "$root" ] || exit "$status"
marker="$root/.claude/.last-verify"
if [ "$status" -ne 0 ]; then
  gone=""
  [ -f "$marker" ] && rm -f "$marker" && gone=" (the earlier one was removed)"
  echo "$me: '$1' exited $status; no verify marker$gone." >&2
  exit "$status"
fi

mkdir -p "$root/.claude" || { echo "$me: cannot create $root/.claude; no marker written." >&2; exit 70; }
cmdline=$(printf '%s ' "$@" | head -1 | cut -c1-200 | tr '\t' ' ')
tmp="$marker.tmp.$$"
{
  echo "writer=$me"
  echo "label=$label"
  echo "command=${cmdline% }"
  echo "started=$started"
  echo "finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$tmp" && touch -r "$stamp" "$tmp" && mv -f "$tmp" "$marker" || {
  rm -f "$tmp"
  echo "$me: the verify passed, but the marker could not be written to $marker." >&2
  exit 70
}
printf '%s\tverify\t%s: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$label" "$(printf '%s' "${cmdline% }" | cut -c1-60)" \
  >> "$root/.claude/.session-log" 2>/dev/null
echo "$me: verify passed ($label); marker written, dated from the run's start ($started)." >&2
exit 0
