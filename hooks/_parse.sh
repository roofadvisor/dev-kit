# Shared JSON field extraction. Sourced by other hooks.
#
# A18 — every hook in this file is now declared globally via hooks/hooks.json
# (the plugin manifest), because that is the ONLY form where $CLAUDE_PLUGIN_ROOT
# resolves — a hook path built from it inside a project's own .claude/settings.json
# is silently skipped, never run, not even with an empty value (measured on CLI
# 2.1.220; docs/BACKLOG.md A18). Global means each hook now matches on EVERY repo
# the user has Claude Code open in, not only ones this kit scaffolded — so the
# very first thing every hook does is call hook_opted_in and exit 0 if the
# current repo never asked for this. That check must be cheap and safe to run
# unconditionally, including outside any git repo and on a repo with no
# .claude/ directory at all: one `git rev-parse`, one `[ -f ]`, nothing parsed,
# no dependency on jq/python3, and it runs BEFORE stdin is ever read.
hook_opted_in() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  # Presence is the whole signal — deliberately not parsed. This file's
  # CONTENT is irrelevant to opt-in status (upgrade.py's --apply and
  # /project-init step 7 are the only writers, and nothing downstream of this
  # check reads a field out of it), so a corrupted-but-present file must still
  # count as opted in: erring toward MORE enforcement on a state we cannot
  # fully trust is the safe direction, and the alternative — parsing it here
  # and failing open on a parse error — would make a corrupted marker file a
  # way to silently go dark, which is the exact failure class A18 exists to
  # close, not reopen one level up.
  [ -f "$root/.claude/.framework-state.json" ]
}

hook_field() {
  local json="$1" key="$2" out=""
  if command -v jq >/dev/null 2>&1; then
    out=$(printf '%s' "$json" | jq -r ".tool_input.${key} // \"\"" 2>/dev/null)
  elif command -v python3 >/dev/null 2>&1; then
    out=$(printf '%s' "$json" | python3 -c "
import sys,json
try: print(json.load(sys.stdin).get('tool_input',{}).get('$key','') or '')
except Exception: print('')
" 2>/dev/null)
  else
    out=$(printf '%s' "$json" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1)
  fi
  printf '%s' "$out"
}

# True when the payload had content but nothing could be extracted — i.e. the
# parser failed rather than the field being genuinely absent.
hook_parse_failed() {
  local json="$1"
  [ -n "$json" ] && ! printf '%s' "$json" | grep -q '"tool_input"'
}

# A10 — enforcement telemetry. Appends: ISO-time <TAB> rule_id <TAB> detail
# to .claude/.enforcement-log at the repo root of the cwd.
#
# HARD PROPERTY: this function must never change control flow. Every failure
# path returns 0 — an unwritable log must never weaken a deny, and a deny must
# never be delayed waiting on telemetry. The guard blocks; the log is a bonus.
log_deny() {
  local rule="$1" detail="${2-}" arm="${3-}"
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
  mkdir -p "$root/.claude" 2>/dev/null || return 0
  # FAIL-CLOSED for secret-class rules: a C-01/KS-* deny is EXPECTED to carry a
  # secret somewhere in the command — as an assignment, a redirect target's
  # payload, or a key embedded in an RPC URL. No regex can enumerate those
  # shapes, so for these rules the detail is withheld entirely; the rule id and
  # timestamp are the telemetry. For every other rule, assignment-shaped values
  # are redacted as defense in depth.
  # WHICH ARM fired is not a secret, and withholding it made a real block and a
  # false positive look identical in the log — 147 of the 165 denies recorded
  # here in six days were C-01, across six different arms, with no way to tell
  # them apart afterwards. The label is a fixed string chosen at the deny site,
  # never anything derived from the command, and it stays inside this column so
  # the log keeps its three fields (session_report.py counts a fourth as
  # malformed).
  case "$rule" in
    C-01|KS-01|KS-02) detail="[withheld — secret-class deny${arm:+: $arm}]" ;;
    *)
      detail=$(printf '%s' "$detail" \
        | sed -E 's/([A-Za-z_]*(KEY|TOKEN|SECRET|PASS(WORD)?|MNEMONIC|CREDENTIAL)[A-Za-z_]*[[:space:]]*=)[^[:space:]]+/\1[REDACTED]/Ig' \
        2>/dev/null) || detail="[redaction failed — detail withheld]" ;;
  esac
  printf '%s\t%s\t%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rule" "$(printf '%s' "$detail" | head -c 120 | tr '\n\t' '  ')" \
    >> "$root/.claude/.enforcement-log" 2>/dev/null || true
  return 0
}
