#!/usr/bin/env bash
# PostToolUse:Bash — records a verify run that passed. Feeds done-check.sh and the
# /project-audit evidence report.
#
# The payload carries no exit code, so "passed" takes two checks (_parse.sh): the
# CLI reported a clean finish, not a reinterpreted non-zero exit, a backgrounded
# run or an interrupt (hook_bash_ran_clean); and the command's exit status IS the
# verify's (hook_is_verify_run). The old `*verify*` substring match recorded
# `gh pr checks 1591 | grep verify-src` as a passing verify (#9 R3).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_parse.sh"
input=$(hook_read_input)
cmd=$(hook_field "$input" "command")
[ -z "$cmd" ] && exit 0
# Every built-in command hook_is_verify_run accepts contains one of these, so most
# Bash calls, in every repo, stop here at the cost of one field read. A project's
# declared commands (.claude/verify.json) pass this filter only if they name verify
# or test too, as `npm run verify:changed` does. One that does not is recorded only
# when the project wraps it in scripts/dev-kit-verify-mark.sh, which writes its own
# marker and needs no hook.
case "$cmd" in *verify*|*test*|*accuracy_report*) ;; *) exit 0 ;; esac
hook_enter_session_dir "$input"
hook_opted_in || exit 0
hook_bash_ran_clean "$input" || exit 0
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
# Declared full and fast commands (2.5.0). An unreadable declaration means none: fewer
# runs count, and done-check says the file could not be read.
decl_full=$(hook_verify_decl "$root" full) || decl_full=""
decl_fast=$(hook_verify_decl "$root" fast) || decl_fast=""
kind=$(hook_is_verify_run "$cmd" "$decl_full" "$decl_fast") || exit 0

mkdir -p "$root/.claude" 2>/dev/null
# A wrapped verify (scripts/dev-kit-verify-mark.sh) has just written its own marker,
# dated from the run's start, and its own session-log line. Leave both: rewritten
# here, the marker would be dated from the end, and an edit a background subagent or
# another session made during the run would pass done-check (2.5.1).
hook_marker_fresh_from_wrapper "$root/.claude/.last-verify" && exit 0
# The marker says which verify ran (done-check names it when it blocks). Its mtime is
# this hook's time, the end of the run.
{
  echo "writer=verify-record"
  echo "label=$kind"
  echo "command=$(printf '%s' "$cmd" | head -1 | cut -c1-200 | tr '\t' ' ')"
  echo "finished=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$root/.claude/.last-verify" 2>/dev/null || touch "$root/.claude/.last-verify"
# First line only, then truncate, then flatten tabs. `cut -c1-60` operates PER
# LINE: given a multi-line command — any `git commit` carrying a heredoc message
# — it emitted one log line per input line, every line after the first a bare
# fragment with no timestamp and no fields. Measured on the kit's own log before
# this fix: 941 of 1036 lines, 91%, were that garbage. /retro and /project-audit
# read this file, so their entire history here was mostly commit prose.
# Tabs are squeezed for the same reason at the field level rather than the line
# level: this is a TSV, and a command containing one silently shifts every
# column after it.
summary=$(printf '%s' "$cmd" | head -1 | cut -c1-60 | tr '\t' ' ')
printf '%s\tverify\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$kind: $summary" \
  >> "$(hook_log_root || echo "$root")/.claude/.session-log" 2>/dev/null
exit 0
