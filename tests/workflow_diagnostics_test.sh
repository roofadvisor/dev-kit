#!/usr/bin/env bash
# The review check's own judgement, run against every session shape, plus the wiring the
# two Claude workflow templates depend on.
#
# A green review check must mean a review happened. On claude-code-action v1 a session
# that never began is reported as SUCCESS: measured 2026-09-19, a review check went green
# in 1.8 seconds having posted no review. "Say why Claude failed" cannot see that, because
# nothing failed. The step covered here judges every run that ran and fails the check when
# no turn was taken, or when the session ran and posted nothing. The one shape that is not
# a defect is the App's workflow validation, which refuses to run when the PR's copy of the
# workflow differs from the default branch.
#
# "Say why Claude failed" is run too, against each failure shape: a spent session window or
# API credit must read as Out of tokens, post one notice per head commit, and publish only the
# limit phrase; any other failure after the model ran must withhold the result text
# (roofadvisor/roof-club#429).
#
# Each step's own shell is extracted from the template and executed under the runner's
# default shell (bash -e), so this tests what ships rather than a copy of it. `gh` is a stub
# that applies the step's own --jq filter to fixture reviews and comments, so the filters
# are tested too.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
REVIEW="$KIT/templates/github/claude-code-review.yml"
TAG="$KIT/templates/github/claude.yml.tmpl"
GATES="$KIT/templates/github/gates.yml"
STEP="A green review means a review happened"
WHY="Say why Claude failed"
pass=0; fail=0
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1"; fail=$((fail+1)); }

if ! command -v jq >/dev/null; then
  echo "FAIL: jq is missing, and the step under test uses jq exactly as the runner does."
  echo "A skipped check is not a passed one (G-03), so this harness fails rather than skips."
  echo "pass=0 fail=1"
  exit 1
fi

extract() {  # step name -> that step's run: block, dedented
  python3 - "$REVIEW" "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
step = re.search(rf"\n      - name: {re.escape(sys.argv[2])}\n(.*?)(?=\n      - |\Z)", text, re.S)
assert step, "the review template has no step by that name"
run = re.search(r"\n        run: \|\n(.*)", step.group(1), re.S)
assert run, "that step has no run: block"
print("\n".join(l[10:] if l.startswith(" " * 10) else l for l in run.group(1).split("\n")))
PY
}
script=$(extract "$STEP")
why_script=$(extract "$WHY")
if [ -z "$script" ] || [ -z "$why_script" ]; then
  echo "FAIL: could not extract the '$STEP' and '$WHY' steps from the template."
  echo "pass=0 fail=1"
  exit 1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
# The gh stub: `api <path> … --jq <expr>` applies <expr> to the fixture for that path, the way
# `gh api --paginate --jq` applies it to each page; `pr review` records the body and exits
# GH_REVIEW_RC. Every call is logged, so a case can assert what was (not) posted.
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
if [ "$1" = api ]; then
  path=$2; expr="."; shift 2
  while [ $# -gt 0 ]; do case "$1" in --jq) expr=$2; shift 2 ;; *) shift ;; esac; done
  [ -n "${GH_FAIL:-}" ] && { echo "gh: HTTP 502" >&2; exit 1; }
  case "$path" in
    */reviews)  jq -r "$expr" "$GH_FIX/reviews.json" ;;
    */comments) jq -r "$expr" "$GH_FIX/comments.json" ;;
    *) exit 1 ;;
  esac
  exit $?
fi
if [ "$1 $2" = "pr review" ]; then exit "${GH_REVIEW_RC:-0}"; fi
exit 1
GH
chmod +x "$tmp/bin/gh"
export GH_LOG="$tmp/gh.log" GH_FIX="$tmp"
STARTED="2026-10-17T12:00:00Z"
fixtures() {  # reviews-json  comments-json
  printf '%s' "$1" > "$tmp/reviews.json"; printf '%s' "$2" > "$tmp/comments.json"
}
OURS='[{"id":7,"user":{"login":"claude[bot]"},"submitted_at":"2026-10-17T12:03:00Z","commit_id":"abc","body":"clean"}]'
OLD='[{"id":6,"user":{"login":"claude[bot]"},"submitted_at":"2026-10-16T09:00:00Z","commit_id":"old","body":"clean"}]'
SOMEONE='[{"id":8,"user":{"login":"chatgpt-codex-connector[bot]"},"submitted_at":"2026-10-17T12:04:00Z","commit_id":"abc","body":"x"}]'
INLINE='[{"id":9,"user":{"login":"claude[bot]"},"created_at":"2026-10-17T12:02:00Z"}]'

rc=0; out=""
judge() {  # payload ("none" to write no file)   workflow_differs ("unset" to leave it out)   [extra VAR=value …]
  local ef="$tmp/execution.json" payload=$1 differs=$2; shift 2
  rm -f "$ef"; : > "$GH_LOG"
  [ "$payload" != "none" ] && printf '%s' "$payload" > "$ef"
  local envs=(EXECUTION_FILE="$ef" PATH="$tmp/bin:$PATH" STARTED_AT="$STARTED" REPO=o/r PR_NUMBER=5 REVIEW_BOT="claude[bot]")
  [ "$differs" != "unset" ] && envs+=(WORKFLOW_DIFFERS="$differs")
  out=$(env "${envs[@]}" "$@" bash -e -c "$script" 2>&1); rc=$?
}
verdict() {  # name  expected_rc  expected_text
  if [ "$rc" -eq "$2" ] && printf '%s' "$out" | grep -qF "$3"; then ok "$1"
  else bad "$1 (rc=$rc want $2; out: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-140))"; fi
}
result() {  # turns  is_error  cost  [result text]
  jq -cn --argjson t "$1" --argjson e "$2" --argjson c "$3" --arg r "${4:-}" \
    '[{"type":"system","subtype":"init"},({"type":"result","subtype":"success","is_error":$e,"num_turns":$t,"total_cost_usd":$c} + (if $r == "" then {} else {result:$r} end))]'
}

echo "the review judgement, per session shape"
fixtures "$OURS" '[]'
judge "$(result 9 false 0)" false;        verdict "a review that ran and posted passes"      0 "The review ran: 9 turns, 1 posted."
judge "$(result 1 false 0)" false;        verdict "a session that never took a turn fails"   1 "The review never happened"
judge "$(result 1 true 0)" false;         verdict "an errored session fails"                 1 "The review errored"
judge "$(result 1 false 0.039)" false;    verdict "a billed session with no turns still fails" 1 "The review never happened"
judge "$(result 7 false 0)" false;        verdict "turns with no cost still pass"            0 "The review ran: 7 turns, 1 posted."
judge "none" false;                       verdict "no execution record fails"                1 "No execution record"
judge '[{"type":"system","subtype":"init"}]' false; verdict "a file with no result event fails" 1 "No result event"
printf -v jsonl '{"type":"result","is_error":false,"num_turns":9}\n{"type":"result","is_error":false,"num_turns":1}'
judge "$jsonl" false;                     verdict "JSONL is read, and the last result wins"  1 "turns=1"
judge '[{"type":"result","is_error":false,"num_turns":"many"}]' false; verdict "a turn count that is not a number fails closed" 1 "The review never happened"
judge "none" true;                        verdict "a PR that edits the workflow is a skip"   0 "skipped by workflow validation"
judge "$(result 1 false 0)" unset;        verdict "an unanswered validation question judges anyway" 1 "The review never happened"
judge "$(result 9 false 0)" false OUT_OF_TOKENS=true; verdict "out of tokens keeps the check red" 1 "title=Out of tokens"

echo "a session that ran must have posted, this run"
fixtures '[]' '[]'
judge "$(result 9 false 0)" false;        verdict "a review that ran but posted nothing fails" 1 "No review was posted"
fixtures "$OLD" '[]'
judge "$(result 9 false 0)" false;        verdict "an older run's review does not count"    1 "No review was posted"
fixtures "$SOMEONE" '[]'
judge "$(result 9 false 0)" false;        verdict "another reviewer's review does not count" 1 "No review was posted"
fixtures '[]' "$INLINE"
judge "$(result 9 false 0)" false;        verdict "an inline comment this run counts"        0 "The review ran: 9 turns, 1 posted."
fixtures "$OURS" '[]'
judge "$(result 9 false 0)" false GH_FAIL=1; verdict "a failed query counts nothing, so fails closed" 1 "No review was posted"
judge "$(result 9 false 0)" false STARTED_AT=; verdict "a missing start time fails closed"   1 "No start time"

echo "why a failed run failed, per failure shape"
why() {  # payload  [extra VAR=value …]
  local ef="$tmp/execution.json" payload=$1; shift
  printf '%s' "$payload" > "$ef"; : > "$GH_LOG"; : > "$tmp/output"
  out=$(env EXECUTION_FILE="$ef" PATH="$tmp/bin:$PATH" GITHUB_OUTPUT="$tmp/output" GITHUB_REPOSITORY=o/r PR_NUMBER=5 HEAD_SHA=abc "$@" bash -e -c "$why_script" 2>&1); rc=$?
}
posted() { grep -c '^pr review' "$GH_LOG"; }
fixtures '[]' '[]'
why "$(result 1 true 0 "You've hit your session limit · resets 10:10pm (UTC)")"
if grep -qx 'out_of_tokens=true' "$tmp/output" && [ "$(posted)" = 1 ] && grep -qF "Limit reached: You've hit your session limit · resets 10:10pm (UTC)." "$GH_LOG"; then
  ok "a spent session window is Out of tokens, posted once as a review"
else bad "a spent session window is not reported as Out of tokens (out: $(tr '\n' ' ' < "$GH_LOG" | cut -c1-140))"; fi
why "$(result 6 true 0.42 "Here is what lib/auth does … Credit balance is too low to access the Anthropic API")"
if grep -qx 'out_of_tokens=true' "$tmp/output" && ! grep -qF 'lib/auth' "$GH_LOG" && grep -qF 'Limit reached: Credit balance is too low.' "$GH_LOG"; then
  ok "spent credit after billed turns is Out of tokens, and only the limit phrase is published"
else bad "spent credit after billed turns leaked or was missed (log: $(tr '\n' ' ' < "$GH_LOG" | cut -c1-140))"; fi
why "$(result 1 true 0 "You've hit your limit · resets 11pm and here is what the diff in lib auth does")"
if grep -qF "resets 11pm." "$GH_LOG" && ! grep -qF 'lib auth' "$GH_LOG"; then ok "text after the reset time is never published"
else bad "text after the reset time was published (log: $(tr '\n' ' ' < "$GH_LOG" | cut -c1-140))"; fi
fixtures '[{"id":3,"user":{"login":"github-actions[bot]"},"commit_id":"abc","body":"**Out of tokens — the automatic review did not run.** x"}]' '[]'
why "$(result 1 true 0 "You've hit your session limit · resets 10:10pm (UTC)")"
if grep -qx 'out_of_tokens=true' "$tmp/output" && [ "$(posted)" = 0 ]; then ok "one notice per head commit: a second is not posted"
else bad "a second out-of-tokens notice was posted on the same commit"; fi
fixtures '[{"id":3,"user":{"login":"github-actions[bot]"},"commit_id":"older","body":"**Out of tokens — the automatic review did not run.** x"}]' '[]'
why "$(result 1 true 0 "You've hit your session limit · resets 10:10pm (UTC)")"
[ "$(posted)" = 1 ] && ok "a notice on an older commit does not stop a new one" || bad "a notice on an older commit suppressed the new one"
fixtures '[]' '[]'
why "$(result 1 true 0 "API Error: 429 rate_limit_error: Rate limit reached for requests per minute")"
if ! grep -q out_of_tokens "$tmp/output" && [ "$(posted)" = 0 ] && printf '%s' "$out" | grep -qF 'title=Claude did not run::API Error: 429'; then
  ok "a throughput 429 is an ordinary failure, not Out of tokens"
else bad "a throughput 429 was read as Out of tokens (out: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-140))"; fi
why "$(result 5 false 0 "the handler logs \"You've hit your session limit · resets 3pm\" when GHL throttles")"
if ! grep -q out_of_tokens "$tmp/output" && [ "$(posted)" = 0 ]; then ok "a limit wording in a result that is not an error is never read as one"
else bad "model text on a non-error result was read as Out of tokens"; fi
why "$(result 5 true 0 "secret model output about lib/auth")"
if printf '%s' "$out" | grep -qF 'title=Claude failed after it ran::result text withheld' && ! printf '%s' "$out" | grep -qF 'secret model output'; then
  ok "an OAuth run (cost 0) that took turns withholds its text — cost alone is not the signal"
else bad "an OAuth run's result text was printed (out: $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-140))"; fi
why "$(result 1 true 0 "Invalid API key · Fix external API key")"
printf '%s' "$out" | grep -qF 'title=Claude did not run::Invalid API key' && ok "a session that never began prints the API's own error" || bad "the API's own error was not printed"
why "$(result 1 true 0 "You've hit your session limit · resets 10:10pm (UTC)")" GH_REVIEW_RC=1
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -qF 'Could not post the out-of-tokens review' && grep -qx 'out_of_tokens=true' "$tmp/output"; then
  ok "a failed post still leaves the annotation and the signal"
else bad "a failed post lost the out-of-tokens signal (rc=$rc)"; fi

echo "the limit pattern, on the messages it must and must not match"
LIMIT_RE=$(printf '%s\n' "$why_script" | sed -n 's/^LIMIT_RE="\(.*\)"$/\1/p')
[ -n "$LIMIT_RE" ] && ok "the pattern was found in the step" || bad "no LIMIT_RE line in '$WHY'"
while IFS='|' read -r text want; do
  got=$(printf '%s' "$text" | grep -oiE "$LIMIT_RE" | head -1 || true)
  [ "$got" = "$want" ] && ok "'${text:0:48}' -> '${want:-no match}'" || bad "'$text': got '$got', want '$want'"
done <<'CASES'
You've hit your session limit · resets 10:10pm (UTC)|You've hit your session limit · resets 10:10pm (UTC)
5-hour limit reached ∙ resets 3pm|5-hour limit reached ∙ resets 3pm
You're out of extra usage · resets 4pm|You're out of extra usage · resets 4pm
You've hit your limit · resets 11pm (UTC)|You've hit your limit · resets 11pm (UTC)
Weekly limit reached ∙ resets Oct 20, 3pm|Weekly limit reached ∙ resets Oct 20, 3pm
Claude AI usage limit reached 1760745600|usage limit reached
Credit balance is too low to access the Anthropic API|Credit balance is too low
You’ve hit your session limit · resets 10:10pm (UTC)|You’ve hit your session limit · resets 10:10pm (UTC)
You've hit your limit · resets 11pm and here is the diff|You've hit your limit · resets 11pm
API Error: 429 rate_limit_error: Rate limit reached for requests per minute|
the GHL client will hit its usage limit under load|
CASES

echo "the wiring those shapes depend on"
has() { grep -qF "$2" "$1"; }
has "$REVIEW" "      - id: claude"                                              && ok "review: the action step has an id"                  || bad "review: the action step has no id, so nothing can read its outputs"
has "$REVIEW" "if: always() && steps.claude.conclusion != 'skipped'"            && ok "review: the judgement runs for every run that ran"   || bad "review: the judgement does not run on every run that ran"
has "$REVIEW" 'EXECUTION_FILE: ${{ steps.claude.outputs.execution_file }}'      && ok "review: the judgement reads the execution file"      || bad "review: the judgement cannot read the execution file"
has "$REVIEW" "id: workflow_validation"                                         && ok "review: the App's validation question is asked"      || bad "review: nothing asks whether this PR edits the workflow"
has "$REVIEW" 'WORKFLOW_DIFFERS: ${{ steps.workflow_validation.outputs.differs }}' && ok "review: the judgement knows about a validation skip" || bad "review: a validation skip would read as a failed review"
has "$REVIEW" 'OUT_OF_TOKENS: ${{ steps.why.outputs.out_of_tokens }}'           && ok "review: the judgement knows a run was out of tokens" || bad "review: an out-of-tokens run would be judged as an ordinary error"
has "$REVIEW" 'STARTED_AT: ${{ steps.started.outputs.at }}'                     && ok "review: the judgement knows when this run began"     || bad "review: the judgement cannot tell this run's review from an older one"
has "$REVIEW" 'HEAD_SHA: ${{ github.event.pull_request.head.sha }}'             && ok "review: the notice is keyed to the head commit"      || bad "review: the out-of-tokens notice cannot be deduplicated per commit"
if python3 - "$REVIEW" <<'PY'
import sys, yaml
c = yaml.safe_load(open(sys.argv[1])).get("concurrency") or {}
sys.exit(0 if c.get("group") == "claude-code-review-${{ github.event.pull_request.number }}" and c.get("cancel-in-progress") is True else 1)
PY
then ok "review: one run per PR, so an older run cannot post inside a newer run's window"
else bad "review: no per-PR concurrency — an older run's review could count as a newer run's"; fi

echo "the review posts where a merge gate reads, and never approves"
allowed=$(grep -oE -- '--allowedTools "[^"]+"' "$REVIEW")
case "$allowed" in *'Bash(gh pr review:*)'*) ok "review: allowed to post a review" ;; *) bad "review: not allowed to post a review" ;; esac
case "$allowed" in *'gh pr comment'*) bad "review: allowed to post an issue comment, which a review-pulling gate never reads" ;; *) ok "review: not allowed to post an issue comment" ;; esac
has "$REVIEW" 'Never `gh pr comment`' && has "$REVIEW" 'never `--approve`' \
  && ok "review: the prompt forbids an issue comment and an approval" || bad "review: the prompt does not forbid an issue comment and an approval"

echo "the review runs against the project's baseline rules"
for want in 'CLAUDE.md' '.claude/rules/org.md' 'always_apply: true' 'the rules index in CLAUDE.md' '.claude/rules/manifest.json' 'docs/DEFINITION.md'; do
  has "$REVIEW" "$want" && ok "review: the prompt reads $want" || bad "review: the prompt never names $want"
done

echo "every template that calls the action gates on either credential, and passes both"
for f in "$REVIEW" "$TAG" "$GATES"; do
  n=$(basename "$f")
  if grep -qF "anthropics/claude-code-action" "$f"; then
    if grep -qF "HAS_CLAUDE_TOKEN: \${{ secrets.ANTHROPIC_API_KEY != '' || secrets.CLAUDE_CODE_OAUTH_TOKEN != '' }}" "$f"; then
      ok "$n gates on either credential being configured"
    else
      bad "$n does not gate on either credential — it fails, or skips, in a repo holding the other one"
    fi
    if grep -qF 'anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}' "$f" && grep -qF 'claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}' "$f"; then
      ok "$n hands the action both credentials"
    else
      bad "$n gates on either credential but does not hand the action both"
    fi
  fi
done
PREFLIGHT="$KIT/templates/github/preflight.yml"
grep -qF "HAS_CLAUDE: \${{ secrets.ANTHROPIC_API_KEY != '' || secrets.CLAUDE_CODE_OAUTH_TOKEN != '' }}" "$PREFLIGHT" \
  && ok "preflight.yml accepts either credential" || bad "preflight.yml demands one credential while the workflows run on either"

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

echo "no filled template names a {{TOKEN}} inside a comment"
# A token is replaced by its value wherever it appears, and a value can run to several lines —
# {{SETUP_CMDS}} does whenever the verify command needs a browser or a second package. Filled
# inside a comment, every line after the first lands outside it and breaks the YAML; only a
# run-block line is indented for a multi-line value. Tokens belong in value positions.
scanned=0; tokened=0; offenders=""
for f in "$KIT"/templates/github/*.yml.tmpl "$KIT"/templates/scaffold/*.yml.tmpl; do
  [ -e "$f" ] || continue
  scanned=$((scanned+1))
  grep -qE '\{\{[A-Z_]+\}\}' "$f" && tokened=$((tokened+1))
  for ln in $(grep -nE '^[[:space:]]*#.*\{\{[A-Z_]+\}\}' "$f" | cut -d: -f1); do
    offenders="$offenders $(basename "$f"):$ln"
  done
done
if [ "$tokened" -eq 0 ]; then
  bad "scanned $scanned filled templates and none carries a token — this check is looking in the wrong place"
elif [ -n "$offenders" ]; then
  bad "a token sits inside a comment at$offenders — a multi-line fill there breaks the YAML"
else
  ok "no token inside a comment across $scanned filled templates ($tokened carry tokens)"
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

echo "the comment workflow's failure printer withholds model output"
# Its "Say why Claude failed" is one jq program. A subscription (OAuth) run reports cost 0
# whatever it did (claude-code-action#1614), so cost alone must not decide to print the text.
tag_jq=$(python3 - "$TAG" <<'PY'
import re, sys
m = re.search(r"jq -r '\n(.*?)\n\s*' \"\$EXECUTION_FILE\"", open(sys.argv[1], encoding="utf-8").read(), re.S)
print(m.group(1) if m else "")
PY
)
if [ -z "$tag_jq" ]; then bad "claude.yml.tmpl: could not extract its failure printer"
else
  got=$(result 5 true 0 "secret model output" | jq -r "$tag_jq")
  case "$got" in *"secret model output"*) bad "claude.yml.tmpl prints an OAuth run's result text after it took turns" ;;
                 *"result text withheld"*) ok "claude.yml.tmpl withholds an OAuth run's text after it took turns" ;;
                 *) bad "claude.yml.tmpl printed neither the text nor the withheld notice: $got" ;; esac
  got=$(result 1 true 0 "Invalid API key" | jq -r "$tag_jq")
  case "$got" in *"Claude did not run::Invalid API key"*) ok "claude.yml.tmpl prints the API's own error when no turn ran" ;;
                 *) bad "claude.yml.tmpl hid the API's own error: $got" ;; esac
fi

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
