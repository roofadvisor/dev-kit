#!/usr/bin/env bash
# The review check's own judgement, run against every session shape, plus the wiring the
# two Claude workflow templates depend on.
#
# A green review check must mean a review happened. On claude-code-action v1 a session
# that never began is reported as SUCCESS: measured 2026-09-19, a review check went green
# in 1.8 seconds having posted no review. "Say why Claude failed" cannot see that, because
# nothing failed. The step covered here judges every run that ran and fails the check when
# no turn was taken. The one shape that is not a defect is the App's workflow validation,
# which refuses to run when the PR's copy of the workflow differs from the default branch.
#
# The step's own shell is extracted from the template and executed, so this tests what
# ships rather than a copy of it.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW="$KIT/templates/github/claude-code-review.yml"
TAG="$KIT/templates/github/claude.yml.tmpl"
GATES="$KIT/templates/github/gates.yml"
STEP="A green review means a review happened"
pass=0; fail=0
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1"; fail=$((fail+1)); }

if ! command -v jq >/dev/null; then
  echo "FAIL: jq is missing, and the step under test uses jq exactly as the runner does."
  echo "A skipped check is not a passed one (G-03), so this harness fails rather than skips."
  echo "pass=0 fail=1"
  exit 1
fi

script=$(python3 - "$REVIEW" "$STEP" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
step = re.search(rf"\n      - name: {re.escape(sys.argv[2])}\n(.*?)(?=\n      - |\Z)", text, re.S)
assert step, "the review template has no step by that name"
run = re.search(r"\n        run: \|\n(.*)", step.group(1), re.S)
assert run, "that step has no run: block"
print("\n".join(l[10:] if l.startswith(" " * 10) else l for l in run.group(1).split("\n")))
PY
)
if [ -z "$script" ]; then
  echo "FAIL: could not extract the '$STEP' step from the template."
  echo "pass=0 fail=1"
  exit 1
fi

tmp=$(mktemp -d)
rc=0; out=""
judge() {  # payload ("none" to write no file)   workflow_differs ("unset" to leave it out)
  local ef="$tmp/execution.json"
  rm -f "$ef"
  [ "$1" != "none" ] && printf '%s' "$1" > "$ef"
  if [ "$2" = "unset" ]; then
    out=$(EXECUTION_FILE="$ef" bash -c "$script" 2>&1); rc=$?
  else
    out=$(EXECUTION_FILE="$ef" WORKFLOW_DIFFERS="$2" bash -c "$script" 2>&1); rc=$?
  fi
}
verdict() {  # name  expected_rc  expected_text
  if [ "$rc" -eq "$2" ] && printf '%s' "$out" | grep -qF "$3"; then ok "$1"
  else bad "$1 (rc=$rc want $2; out: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-110))"; fi
}
result() {  # turns  is_error  cost
  printf '[{"type":"system","subtype":"init"},{"type":"result","subtype":"success","is_error":%s,"num_turns":%s,"total_cost_usd":%s}]' "$2" "$1" "$3"
}

echo "the review judgement, per session shape"
judge "$(result 9 false 0)" false;        verdict "a review that ran passes"                 0 "The review ran: 9 turns."
judge "$(result 1 false 0)" false;        verdict "a session that never took a turn fails"   1 "The review never happened"
judge "$(result 1 true 0)" false;         verdict "an errored session fails"                 1 "The review errored"
judge "$(result 1 false 0.039)" false;    verdict "a billed session with no turns still fails" 1 "The review never happened"
judge "$(result 7 false 0)" false;        verdict "turns with no cost still pass"            0 "The review ran: 7 turns."
judge "none" false;                       verdict "no execution record fails"                1 "No execution record"
judge '[{"type":"system","subtype":"init"}]' false; verdict "a file with no result event fails" 1 "No result event"
printf -v jsonl '{"type":"result","is_error":false,"num_turns":9}\n{"type":"result","is_error":false,"num_turns":1}'
judge "$jsonl" false;                     verdict "JSONL is read, and the last result wins"  1 "turns=1"
judge "none" true;                        verdict "a PR that edits the workflow is a skip"   0 "skipped by workflow validation"
judge "$(result 1 false 0)" unset;        verdict "an unanswered validation question judges anyway" 1 "The review never happened"

echo "the wiring those shapes depend on"
has() { grep -qF "$2" "$1"; }
has "$REVIEW" "      - id: claude"                                              && ok "review: the action step has an id"                  || bad "review: the action step has no id, so nothing can read its outputs"
has "$REVIEW" "if: always() && steps.claude.conclusion != 'skipped'"            && ok "review: the judgement runs for every run that ran"   || bad "review: the judgement does not run on every run that ran"
has "$REVIEW" 'EXECUTION_FILE: ${{ steps.claude.outputs.execution_file }}'      && ok "review: the judgement reads the execution file"      || bad "review: the judgement cannot read the execution file"
has "$REVIEW" "id: workflow_validation"                                         && ok "review: the App's validation question is asked"      || bad "review: nothing asks whether this PR edits the workflow"
has "$REVIEW" 'WORKFLOW_DIFFERS: ${{ steps.workflow_validation.outputs.differs }}' && ok "review: the judgement knows about a validation skip" || bad "review: a validation skip would read as a failed review"

echo "every template that calls the action gates on the credential"
for f in "$REVIEW" "$TAG" "$GATES"; do
  n=$(basename "$f")
  if grep -qF "anthropics/claude-code-action" "$f"; then
    if grep -qF "HAS_CLAUDE_TOKEN: \${{ secrets.CLAUDE_CODE_OAUTH_TOKEN != '' }}" "$f"; then
      ok "$n gates on the token being configured"
    else
      bad "$n calls the action with no credential gate — it fails on every run in a repo without the secret"
    fi
  fi
done

echo "the comment workflow stays in tag mode"
# `prompt:` on a comment or issue event switches the action to agent mode, which hands
# Claude the fixed text and never the comment that summoned it, and posts no reply
# (claude-code-action v1: src/modes/detector.ts).
if grep -qE '^\s+prompt:' "$TAG"; then
  bad "claude.yml.tmpl sets prompt:, which forces agent mode — @claude would never be read"
else
  ok "claude.yml.tmpl sets no prompt:, so @claude is read in tag mode"
fi
if grep -qF -- "--append-system-prompt" "$TAG"; then
  ok "claude.yml.tmpl carries its standing instructions in the system prompt"
else
  bad "claude.yml.tmpl has no --append-system-prompt, so its standing instructions reach nothing"
fi

echo "the comment workflow installs what verify.yml installs"
# claude.yml.tmpl asks Claude to run the verify command, and nothing goes red when its install
# is incomplete: the failure lands inside Claude's session. Filling both workflows from the same
# tokens is what makes verify.yml's green run the proof, so both sides are pinned — to a run-block
# line rather than any mention, because a comment naming a token would satisfy a looser match.
VERIFY_TMPL="$KIT/templates/scaffold/verify.yml.tmpl"
for f in "$TAG" "$VERIFY_TMPL"; do
  n=$(basename "$f")
  if grep -qE '^[[:space:]]+\{\{SETUP_CMDS\}\}[[:space:]]*$' "$f"; then
    ok "$n installs from {{SETUP_CMDS}}"
  else
    bad "$n no longer installs from {{SETUP_CMDS}} — the two workflows stop sharing a proven install"
  fi
done
if grep -qE '^[[:space:]]+\{\{VERIFY\}\}[[:space:]]*$' "$VERIFY_TMPL"; then
  ok "verify.yml.tmpl runs {{VERIFY}}"
else
  bad "verify.yml.tmpl no longer runs {{VERIFY}} — its green run proves nothing about the command claude.yml asks for"
fi
if grep -qF 'Bash({{VERIFY}})' "$TAG"; then
  ok "claude.yml.tmpl lets Claude run {{VERIFY}}"
else
  bad "claude.yml.tmpl does not allow Bash({{VERIFY}}) — a headless run would deny the verify it asks for"
fi

echo "a review with a prompt can still post"
# Agent mode installs no comment tools unless they are named, and a headless run denies
# any tool it was not given (claude-code-action v1: src/mcp/install-mcp-server.ts).
if grep -qF "mcp__github_inline_comment__create_inline_comment" "$REVIEW"; then
  ok "the review names the tools it needs to post"
else
  bad "the review has a prompt but no posting tools — it would run and the PR would see nothing"
fi

echo "both templates explain a failure"
for f in "$REVIEW" "$TAG"; do
  n=$(basename "$f")
  if grep -qF "Say why Claude failed" "$f"; then ok "$n prints the hidden reason on failure"
  else bad "$n leaves a failure as a bare is_error:true"; fi
done

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
