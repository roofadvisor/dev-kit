#!/usr/bin/env bash
# PostToolUse:Bash — records a verify run that passed. Feeds done-check.sh and the
# /project-audit evidence report.
#
# "Passed" is read from the event: PostToolUse fires only for a successful tool call
# (a non-zero exit arrives as PostToolUseFailure, CLI 2.1.252) and carries no exit
# code, so a run counts only when the verify's status IS the command's
# (hook_is_verify_run, _parse.sh). The old `*verify*` substring match recorded
# `gh pr checks 1591 | grep verify-src` as a passing verify (#9 R3).
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_parse.sh"
input=$(hook_read_input)
hook_enter_session_dir "$input"
hook_opted_in || exit 0
cmd=$(hook_field "$input" "command")
[ -z "$cmd" ] && exit 0

# Only the success event records. hooks.json wires PostToolUse; a payload naming any
# other event (a failure, were this ever wired there) never does.
event=$(hook_top_field "$input" hook_event_name)
[ -n "$event" ] && [ "$event" != "PostToolUse" ] && exit 0
# A background run reports success when it STARTS (its result is a task id), so it
# has passed nothing yet.
case "$(hook_field "$input" run_in_background)" in true|True) exit 0 ;; esac
hook_is_verify_run "$cmd" || exit 0

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
mkdir -p "$root/.claude" 2>/dev/null
touch "$root/.claude/.last-verify"
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
printf '%s\tverify\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$summary" \
  >> "$root/.claude/.session-log" 2>/dev/null
exit 0
