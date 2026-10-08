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
# no dependency on jq/python3. It never reads stdin itself; done-check and
# verify-record read the payload first only to learn which tree the session is
# in (hook_enter_session_dir).
hook_opted_in() {
  local root out gitdir common
  out=$(git rev-parse --show-toplevel --git-dir --git-common-dir 2>/dev/null) || return 1
  root=${out%%$'\n'*}; out=${out#*$'\n'}; gitdir=${out%%$'\n'*}; common=${out#*$'\n'}
  # Presence is the whole signal — deliberately not parsed. This file's
  # CONTENT is irrelevant to opt-in status (upgrade.py's --apply and
  # /project-init step 7 are the only writers, and nothing downstream of this
  # check reads a field out of it), so a corrupted-but-present file must still
  # count as opted in: erring toward MORE enforcement on a state we cannot
  # fully trust is the safe direction, and the alternative — parsing it here
  # and failing open on a parse error — would make a corrupted marker file a
  # way to silently go dark, which is the exact failure class A18 exists to
  # close, not reopen one level up.
  [ -f "$root/.claude/.framework-state.json" ] && return 0
  # A linked worktree carries only what is committed, so a repo whose marker is
  # untracked opted in from its main checkout: ask there too. Without this, a hook
  # that enters the session's worktree (hook_enter_session_dir) would go dark in it.
  # Only a real linked worktree has one: its git dir sits under the common dir's
  # worktrees/, and that common dir is a checkout's own .git. A --separate-git-dir
  # repo or a bare repo's worktree has no main checkout, and a marker in some
  # folder above its git dir is not its opt-in. One git call either way.
  case "$gitdir" in "$common"/worktrees/*) ;; *) return 1 ;; esac
  [ "${common##*/}" = .git ] || return 1
  [ -f "${common%/.git}/.claude/.framework-state.json" ]
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

# The hook's stdin payload, or "" when there is none. Guarded on a terminal, so a
# hook run by hand, or by a harness that inherits a TTY, never waits on the keyboard.
hook_read_input() { [ -t 0 ] && return 0; cat; }

# Top-level payload fields; hook_field above reads only tool_input.*. A boolean
# comes back as "true"/"false", an absent field as "".
hook_top_field() {
  local json="$1" key="$2" out=""
  [ -z "$json" ] && return 0
  if command -v jq >/dev/null 2>&1; then
    out=$(printf '%s' "$json" | jq -r --arg k "$key" \
      'if type == "object" and has($k) and .[$k] != null then .[$k] | tostring else "" end' 2>/dev/null)
  elif command -v python3 >/dev/null 2>&1; then
    out=$(printf '%s' "$json" | python3 -c "
import sys, json
try:
    v = json.load(sys.stdin).get(sys.argv[1])
    print('' if v is None else json.dumps(v) if isinstance(v, bool) else v)
except Exception:
    print('')
" "$key" 2>/dev/null)
  else
    out=$(printf '%s' "$json" | sed -nE "s/.*\"${key}\"[[:space:]]*:[[:space:]]*(\"([^\"]*)\"|(true|false)).*/\2\3/p" | head -1)
  fi
  printf '%s' "$out"
}

# Move to the directory Claude is working in. A hook process starts where the
# session launched, and CLAUDE_PROJECT_DIR stays on the main checkout when the
# session works in a worktree, so `git rev-parse` from the hook's own cwd judges
# the wrong tree: on 2026-09-30 a worktree session was blocked by the main
# checkout's stray files, and its verify marker landed in the main checkout. Every
# payload carries `cwd`, where Claude actually is (CLI 2.1.252 input schema). With
# no payload, or no such directory, the hook's own cwd stands.
hook_enter_session_dir() {
  local d; d=$(hook_top_field "$1" cwd)
  if [ -n "$d" ] && [ -d "$d" ]; then cd "$d" 2>/dev/null || true; fi
  return 0
}

# True when the command RUNS the verify (or a test runner) and that run's exit
# status is the command's own. The payload carries no exit code, and the CLI
# reports some non-zero exits as success (hook_bash_ran_clean refuses those), so
# the command must also be shaped so that its status IS the verify's (#9 R3):
#  - mentioning is not running: `gh pr checks 1591 | grep verify-src` and
#    `cat scripts/verify.sh` both reset the marker under the old *verify* match;
#  - `verify | tail` without pipefail, `verify; echo` and `verify &` exit with
#    someone else's status, and after `x || verify` the verify may never have run;
#  - a heredoc body is data, but the lines after its terminator are commands;
#  - a # comment runs to the end of its line, and no further.
# A command it cannot parse is not a verify. A missed record costs one block, and
# the retry passes (R1); a false one certifies a change nothing checked.
hook_is_verify_run() {
  command -v python3 >/dev/null 2>&1 || return 1
  python3 - "$1" <<'PY'
import re, shlex, sys

if re.search(r"\\[;&|]|(['\"])[;&|]+\1", sys.argv[1]):
    sys.exit(1)
# The shell drops a backslash-newline before it tokenizes.
lines = sys.argv[1].replace("\\\n", "").split("\n")
# Skip each heredoc body through its terminator, then keep reading: the lines after
# it are commands again. A heredoc it cannot read, or one never closed, is refused.
HD = re.compile(r"<<(-?)[ \t]*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")
kept, i = [], 0
while i < len(lines):
    line = lines[i]
    kept.append(line)
    i += 1
    bare = line.replace("<<<", "   ")
    if "<<" in bare and not HD.search(bare):
        sys.exit(1)
    for m in HD.finditer(bare):
        tabs, word = m.group(1) == "-", m.group(3)
        while i < len(lines) and (lines[i].lstrip("\t") if tabs else lines[i]) != word:
            i += 1
        if i >= len(lines):
            sys.exit(1)
        i += 1
# A newline separates commands unless the line ends in an operator that continues
# it. The `;` goes AFTER the newline, so a # comment, which shlex runs to the end of
# its line, cannot swallow the commands on the lines below.
cmd = "\n;".join(kept)
# shlex ends a word at `#`; bash keeps a `#` inside a word as a literal.
cmd = re.sub(r"(?<=[^\s;&|()<>])#", "\x00", cmd)
lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
lex.whitespace_split = True
try:
    toks = list(lex)
except ValueError:
    sys.exit(1)
_t = []
for t in toks:
    if t == ";" and _t and _t[-1] in ("&&", "||", "|", "|&"):
        continue
    _t.append(t)
toks = _t

OPS = {"&&", "||", ";", "|", "&", "|&", ";;", ";&", ";;&", "&|"}
REDIR = {">&", "<&", "&>", "&>>", ">|"}
MASK = {";", "&", ";;", ";&", ";;&", "&|"}
segs, ops = [[]], []
for t in toks:
    if t and all(c in "();<>|&" for c in t) and t not in OPS and t not in REDIR \
            and any(c in ";|&" for c in t):
        sys.exit(1)  # an operator run like `;(` or `|(`: cannot tell what masks what
    if t in OPS:
        ops.append(t)
        segs.append([])
    else:
        segs[-1].append(t)

if "||" in ops:
    sys.exit(1)


def pipefail_on(upto):
    on = False
    for idx, s in enumerate(segs[:upto]):
        if s[:1] != ["set"]:
            continue
        if ops[idx] in ("|", "|&") or (idx > 0 and ops[idx - 1] in ("|", "|&", "&&", "||")):
            continue
        for k in range(2, len(s)):
            if s[k - 1] == "--":
                break
            if s[k] == "pipefail" and "o" in s[k - 1]:
                on = s[k - 1].startswith("-") if s[k - 1][:1] in "-+" else on
    return on


def runs_verify(words):
    while words and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[0]):
        words = words[1:]
    if not words:
        return False
    head, rest = words[0], words[1:]
    if head.rsplit("/", 1)[-1] in ("verify", "verify.sh"):
        return True
    if head in ("bash", "sh", "zsh") and rest and rest[0].rsplit("/", 1)[-1] in ("verify", "verify.sh"):
        return True
    if head == "npm":
        return rest[:2] in (["run", "verify"], ["run-script", "verify"], ["run", "test"]) or rest[:1] == ["test"]
    if head in ("pnpm", "yarn", "bun"):
        return rest[:1] in (["verify"], ["test"]) or rest[:2] in (["run", "verify"], ["run", "test"])
    if head in ("make", "just"):
        return rest[:1] == ["verify"]
    if head == "pytest" or (head in ("python", "python3") and rest[:2] == ["-m", "pytest"]):
        return True
    if head == "vitest" or (head == "npx" and rest[:1] == ["vitest"]):
        return True
    if head == "forge":
        return rest[:1] == ["test"]
    if head == "node":
        # /gate runs `node .../accuracy_report.mjs`, whose child gates execSync
        # beneath it where no PostToolUse can see them.
        return bool(rest) and rest[0].endswith("accuracy_report.mjs")
    return False


for i, words in enumerate(segs):
    if not runs_verify(words):
        continue
    after = ops[i:]
    if after[:1] in (["|"], ["|&"]) and not pipefail_on(i):
        continue
    if any(o in MASK for o in after):
        continue
    sys.exit(0)
sys.exit(1)
PY
}

# True when the CLI reported this Bash call as a clean finish. PostToolUse is not
# "passed": the CLI fires PostToolUseFailure only for an exit it judges an error,
# and it reinterprets some non-zero exits as success (exit 1 from a line ending in
# grep, diff, test or git diff arrives as "No matches found" or "Files differ" in
# returnCodeInterpretation). A run moved to the background, by the two-minute
# timeout or by the user, reports success the moment it moves; an interrupt does
# not throw. All of those arrive as PostToolUse (CLI 2.1.252's Bash output schema).
# A payload without tool_response is judged by the rest; one it cannot read is not.
hook_bash_ran_clean() {
  command -v python3 >/dev/null 2>&1 || return 1
  printf '%s' "$1" | python3 -c '
import json, sys
try:
    p = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not isinstance(p, dict) or p.get("hook_event_name") not in (None, "", "PostToolUse"):
    sys.exit(1)
ti = p.get("tool_input")
if isinstance(ti, dict) and ti.get("run_in_background") is True:
    sys.exit(1)
if "tool_response" in p:
    r = p["tool_response"]
    if not isinstance(r, dict) or r.get("interrupted") is True or r.get("returnCodeInterpretation"):
        sys.exit(1)
    if r.get("backgroundTaskId") or r.get("timedOutAfterMs") is not None:
        sys.exit(1)
    if any(r.get(k) is True for k in ("backgroundedByUser", "backgroundedByTurnAbort", "backgroundedToDeliverMessage")):
        sys.exit(1)
sys.exit(0)
'
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
