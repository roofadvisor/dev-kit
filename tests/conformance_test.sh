#!/usr/bin/env bash
# O4 tier 1 — mechanical conformance: the templates a scaffold is assembled
# from must actually compose. Catches the class the GHL-MCP audit hit in the
# kit itself: a spec that references pieces which do not exist, workflows that
# do not parse, and module manifests that do not resolve against the registry.
#
# Tier 2 (behavioral: agent-run scaffold per module combo, verify green on the
# empty scaffold, full-spec plan/execute parity, failing-verify-keeps-state) is
# documented in docs/acceptance/O4-protocol.md — it needs an agent, not bash.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok()  { echo "  PASS  $1"; pass=$((pass+1)); }
bad() { echo "  FAIL  $1"; fail=$((fail+1)); }

# Dependency preflight — fail loud ONCE, not ten confusing times (G-03).
if ! python3 -c "import yaml" 2>/dev/null; then
  echo "  FAIL  PyYAML is required for the YAML checks: pip3 install pyyaml==6.0.3"
  echo "pass=0 fail=1"
  exit 1
fi

echo "the plugin is installable as documented"
# Every documented install path failed with "Marketplace file not found" until
# this manifest existed — README and START_HERE described a flow nobody had run.
# These assertions are what stop that from silently recurring.
MKT="$KIT/.claude-plugin/marketplace.json"
if [ -f "$MKT" ]; then
  ok "marketplace.json exists (without it, 'claude plugin marketplace add' cannot work)"
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$MKT" 2>/dev/null; then
    ok "marketplace.json parses"
    # A manifest that parses but points nowhere is the same shape as a registry
    # row claiming enforcement that is not wired: valid, and useless.
    python3 - "$KIT" "$MKT" <<'PY'
import json, os, sys
kit, path = sys.argv[1], sys.argv[2]
m = json.load(open(path))
plugins = m.get("plugins") or []
problems = []
if not m.get("name"):
    problems.append("marketplace has no name")
if not plugins:
    problems.append("marketplace declares no plugins")
for p in plugins:
    src = p.get("source")
    if not isinstance(src, str):
        problems.append(f"{p.get('name')}: non-path source {src!r} not checked here")
        continue
    manifest = os.path.join(kit, src, ".claude-plugin", "plugin.json")
    if not os.path.exists(manifest):
        problems.append(f"{p.get('name')}: source {src!r} has no .claude-plugin/plugin.json")
        continue
    declared = json.load(open(manifest)).get("name")
    if declared != p.get("name"):
        problems.append(f"marketplace calls it {p.get('name')!r}, plugin.json calls it {declared!r}")
for problem in problems:
    print(f"  FAIL  {problem}")
sys.exit(1 if problems else 0)
PY
    if [ $? -eq 0 ]; then
      ok "every marketplace plugin resolves to a real plugin.json with a matching name"
    else
      fail=$((fail+1))
    fi
  else bad "marketplace.json does not parse as JSON"; fi
else
  bad "no .claude-plugin/marketplace.json — the documented install path cannot work"
fi

echo
echo "workflows parse"
# Both shapes: a .tmpl renders to YAML once its {{TOKENS}} are filled, and globbing only
# *.yml would drop it out of this check the moment a workflow template gains a token.
for f in "$KIT"/templates/github/*.yml "$KIT"/templates/github/*.yml.tmpl; do
  [ -e "$f" ] || continue
  if python3 -c "
import re, sys, yaml
yaml.safe_load(re.sub(r'\{\{[A-Z_]+\}\}', 'dummy', open(sys.argv[1]).read()))" "$f" 2>/dev/null; then
    ok "$(basename "$f") parses"
  else bad "$(basename "$f") does not parse as YAML"; fi
done

echo
echo "the kit's own CI pins PyYAML identically in both workflows (A22)"
# gates.yml and main-verify.yml each install PyYAML independently (they are
# different jobs on different triggers — PR vs push-to-master — so neither can
# just depend on the other having run). A22 pinned both to stop the version
# drifting apart between two runs of an unchanged commit; nothing but a code
# comment stopped a future edit from re-diverging them one file at a time.
# This makes that mechanical instead of a request.
GATES_PIN=$(grep -ohE 'pip install pyyaml==[0-9][0-9.]*' "$KIT/.github/workflows/gates.yml" | head -1)
MAIN_PIN=$(grep -ohE 'pip install pyyaml==[0-9][0-9.]*' "$KIT/.github/workflows/main-verify.yml" | head -1)
if [ -z "$GATES_PIN" ]; then
  bad "gates.yml has no pinned 'pip install pyyaml==X.Y.Z' (bare/unpinned install reopens A22)"
elif [ -z "$MAIN_PIN" ]; then
  bad "main-verify.yml has no pinned 'pip install pyyaml==X.Y.Z' (bare/unpinned install reopens A22)"
elif [ "$GATES_PIN" != "$MAIN_PIN" ]; then
  bad "gates.yml pins '$GATES_PIN' but main-verify.yml pins '$MAIN_PIN' — the exact divergence A22 fixed, reintroduced"
else
  ok "both workflows pin identical: $GATES_PIN"
fi

echo "scaffold templates exist (and compose files parse)"
for f in docker-compose.yml.tmpl docker-compose.multi.yml.tmpl CLAUDE.md.tmpl gitignore.tmpl env.example.tmpl verify.yml.tmpl dev-reset.sh.tmpl nginx-lb.conf guard-local.sh; do
  if [ -s "$KIT/templates/scaffold/$f" ]; then ok "templates/scaffold/$f"; else bad "templates/scaffold/$f MISSING or empty"; fi
done
for f in docker-compose.yml.tmpl docker-compose.multi.yml.tmpl verify.yml.tmpl; do
  # A template's conformance property: it renders to valid YAML once every
  # {{TOKEN}} is filled — so fill them with dummies, then parse.
  if python3 -c "
import re, sys, yaml
src = open(sys.argv[1]).read()
yaml.safe_load(re.sub(r'\{\{[A-Z_]+\}\}', 'dummy', src))" "$KIT/templates/scaffold/$f" 2>/dev/null; then
    ok "$f renders to valid YAML"
  else bad "$f does not render to valid YAML"; fi
done

echo "executables are executable"
for f in "$KIT"/hooks/*.sh "$KIT"/templates/scaffold/guard-local.sh; do
  [ -x "$f" ] && ok "$(basename "$f") +x" || bad "$(basename "$f") not executable"
done

echo "hooks/hooks.json (A18 — the plugin-declared manifest) is well-formed and complete"
HJ="$KIT/hooks/hooks.json"
if [ -f "$HJ" ]; then
  ok "hooks/hooks.json exists"
  if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$HJ" 2>/dev/null; then
    ok "hooks/hooks.json parses"
    # Every command references a real, executable hooks/*.sh file — a typo'd
    # or stale path here is invisible until a live session hits it, which is
    # exactly the class of gap this file exists to catch mechanically instead.
    hj_result=$(python3 - "$KIT" "$HJ" <<'PY'
import json, os, re, sys
kit, path = sys.argv[1], sys.argv[2]
data = json.load(open(path))
problems = []
seen = set()
for event, entries in (data.get("hooks") or {}).items():
    for entry in entries or []:
        for h in entry.get("hooks") or []:
            cmd = h.get("command", "")
            m = re.search(r'\$\{CLAUDE_PLUGIN_ROOT\}/(hooks/[A-Za-z0-9_.-]+\.sh)', cmd)
            if not m:
                problems.append(f"{event}: command does not reference \\${{CLAUDE_PLUGIN_ROOT}}/hooks/*.sh: {cmd!r}")
                continue
            rel = m.group(1)
            seen.add(os.path.basename(rel))
            full = os.path.join(kit, rel)
            if not os.path.isfile(full):
                problems.append(f"{event}: {rel} does not exist")
            elif not os.access(full, os.X_OK):
                problems.append(f"{event}: {rel} exists but is not executable")
for p in problems:
    print(f"PROBLEM\t{p}")
print("SEEN\t" + ",".join(sorted(seen)))
PY
)
    hj_problems=$(printf '%s\n' "$hj_result" | grep '^PROBLEM' | sed 's/^PROBLEM\t//')
    hj_seen=$(printf '%s\n' "$hj_result" | grep '^SEEN' | sed 's/^SEEN\t//')
    if [ -z "$hj_problems" ]; then
      ok "every hooks.json command resolves to a real, executable hooks/*.sh file"
    else
      printf '%s\n' "$hj_problems" | while IFS= read -r p; do bad "$p"; done
    fi

    # Drift check: hooks.json (global, plugin-declared, A18) and this repo's own
    # .claude/settings.json (project-local, repo-relative — a deliberately
    # different case, see its _comment) should still name the SAME set of hook
    # scripts. A hook added to one and not the other is exactly the kind of gap
    # that looks fine until the missing side is the one that mattered.
    sj_seen=$(python3 -c "
import json
d = json.load(open('$KIT/.claude/settings.json'))
names = set()
for entries in (d.get('hooks') or {}).values():
    for entry in entries:
        for h in entry.get('hooks') or []:
            # A23 follow-up: settings.json's own commands are now wrapped in a
            # literal quote pair (fix for word-splitting on a spaced project
            # path) -- strip it before taking the basename, or a trailing
            # quote character rides along and never matches hooks.json's
            # unquoted names. chr(34), not a literal \", since this whole
            # block is itself embedded in a double-quoted bash string.
            names.add(h['command'].strip(chr(34)).rsplit('/', 1)[-1])
print(','.join(sorted(names)))
")
    if [ "$hj_seen" = "$sj_seen" ]; then
      ok "hooks.json and .claude/settings.json declare the same hook scripts ($hj_seen)"
    else
      bad "hooks.json ($hj_seen) and .claude/settings.json ($sj_seen) declare different hook scripts"
    fi
  else
    bad "hooks/hooks.json does not parse as JSON"
  fi
else
  bad "no hooks/hooks.json — A18's plugin-declared hooks cannot resolve \${CLAUDE_PLUGIN_ROOT} without it"
fi

echo "every hooks.json-declared hook opts itself in (hook_opted_in, A18)"
# hooks.json is global — it matches on every repo the user has open, so every
# script it points at MUST gate on hook_opted_in before doing anything else.
# _parse.sh itself is a sourced library, never invoked directly by the harness,
# so it is exempt; every other hooks/*.sh file is a real entry point.
for f in "$KIT"/hooks/*.sh; do
  base="$(basename "$f")"
  [ "$base" = "_parse.sh" ] && continue
  if grep -q 'hook_opted_in' "$f"; then
    ok "$base calls hook_opted_in"
  else
    bad "$base never calls hook_opted_in — it would run unconditionally on every repo the user has open"
  fi
done

echo "every registry section resolves as a module manifest (with the always-on core)"
T="$(mktemp -d)"
section_failures=$(python3 - "$KIT" "$T" <<'PY'
import sys, json, subprocess
kit, tmp = sys.argv[1], sys.argv[2]
sys.path.insert(0, f"{kit}/scripts")
from render_registry import parse_registry
sections, _ = parse_registry(f"{kit}/templates/rules/REGISTRY.md")
always = {r for s in sections for r in s["rows"] if s["title"] in ("Core", "Guards", "Silent degradation")}
failures = 0
for s in sections:
    if not s["rows"]:
        continue
    json.dump({"rules": sorted(always | set(s["rows"])), "overrides": {}}, open(f"{tmp}/m.json", "w"))
    r = subprocess.run(["python3", f"{kit}/scripts/render_registry.py",
                        "--plugin", kit, "--manifest", f"{tmp}/m.json", "--validate"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        failures += 1
        print(f"SECTION-FAIL {s['title']}: {r.stderr.strip()}", file=sys.stderr)
print(failures)
PY
)
rm -rf "$T"
if [ "$section_failures" -eq 0 ]; then ok "all registry sections resolve as manifests"; else bad "$section_failures registry section manifest(s) failed to resolve"; fi

echo "spec-mandated artifacts exist (the missing-piece class)"
# Two layers: (a) literal templates/ paths scraped from the init spec, and
# (b) a CURATED list of everything Step 3/10 mandates by prose — directory
# copies, brace patterns, and named files a path-regex cannot see. The curated
# list is a test fixture: when the spec adds an output, add it here (the
# gate_trio/G-05 discipline applied to the spec itself).
refs=$(grep -ohE 'templates/[a-z]+/[A-Za-z0-9._-]+\.(md|yml|tmpl|sh|py|conf|json)' \
  "$KIT/skills/project-init/SKILL.md" "$KIT/skills/project-init/references/scaffold-spec.md" 2>/dev/null | sort -u)
MANDATED="
templates/process/LIFECYCLE.md
templates/process/DEFINITION.md
templates/process/ENFORCEMENT.md
templates/process/TEST_STRATEGY.md
templates/process/CADENCE.md
templates/process/PR.template.md
templates/process/ADR.template.md
templates/process/SPEC.template.md
templates/tests/guard_tests.py
templates/tests/guard_tests.ts
templates/tests/statelessness_test.py
templates/github/gates.yml
templates/github/claude.yml.tmpl
templates/github/claude-code-review.yml
templates/github/notion-sync.yml
templates/github/preflight.yml
templates/github/bug.yml
templates/github/feature.yml
templates/org/ORG.template.yml
templates/notion/WORK_DB_SCHEMA.md
scripts/notion_sync.py
scripts/check_fixtures.py
scripts/check_contract_pin.py
scripts/check_guess_lists.py
scripts/check_rollback.py
scripts/check_statelessness.py
scripts/check_commits.py
scripts/check_raw_sql.py
scripts/check_pure_imports.py
scripts/check_catch_empty.py
scripts/check_log_hygiene.py
scripts/check_test_count.py
scripts/upgrade.py
scripts/render_registry.py
scripts/session_report.py
tests/hooks_test.sh
"
missing=0; total=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  total=$((total+1))
  [ -e "$KIT/$f" ] || { bad "referenced by the init spec but missing: $f"; missing=$((missing+1)); }
done <<< "$refs
$MANDATED"
[ "$missing" -eq 0 ] && ok "every spec-mandated artifact exists ($total checked: scraped + curated)"

echo
echo "SKILL.md names a real, correctly-scoped source for every .github/workflows/ output (A19)"
# The "spec-mandated artifacts" check above only proves each template FILE
# exists somewhere under templates/ — it does not prove SKILL.md's own prose
# points the scaffolder at the right one for a given destination. Concretely,
# step 10 used to fold verify.yml into the templates/github/ list meant for
# claude.yml/claude-code-review.yml/notion-sync.yml, but templates/github/ has
# no verify.yml — the repo has templates/scaffold/verify.yml.tmpl instead. And
# gates.yml/preflight.yml (step 11) named a destination with no source clause
# at all — the "spec-mandated" check above passed anyway, because it only
# scrapes/curates paths, never checks that SKILL.md's prose actually names
# them next to the destination. Encode the correct destination -> source
# mapping once here and prove SKILL.md's text cites it verbatim — not just
# that the source happens to exist in isolation.
#
# Follow-up (PR #31 review): the first cut of this check only proved src_rel
# appears SOMEWHERE in SKILL.md, never that it appears NEXT TO its own dest.
# Swap two workflows' source clauses — even just two of the four packed onto
# step 10's single line — and every check above still found its src_rel text
# sitting under the *other* destination and passed, reintroducing exactly the
# mis-scoping A19 fixed. Every dest/src pair here is written as adjacent
# backtick-quoted tokens ("`<dest>` ... from `<src>`", nothing else
# backtick-quoted in between, even mid-line) so walking the backtick-token
# stream in document order and requiring the token right after `dest` to
# cite `src` ties each source to its own destination instead of the file at
# large.
while IFS= read -r line; do
  case "$line" in
    PASS*) ok "${line#PASS }" ;;
    FAIL*) bad "${line#FAIL }" ;;
  esac
done < <(python3 - "$KIT" <<'PY'
import os, re, sys
import yaml

kit = sys.argv[1]
skill = open(os.path.join(kit, "skills/project-init/SKILL.md")).read()

# .github/workflows/<dest> -> (source path under $KIT that SKILL.md must cite
# verbatim as the very next backtick-quoted token after dest, whether it is
# a .tmpl that must also render to valid YAML)
WORKFLOWS = [
    ("verify.yml",             "templates/scaffold/verify.yml.tmpl",      True),
    ("claude.yml",             "templates/github/claude.yml.tmpl",        True),
    ("claude-code-review.yml", "templates/github/claude-code-review.yml", False),
    ("notion-sync.yml",        "templates/github/notion-sync.yml",        False),
    ("gates.yml",              "templates/github/gates.yml",              False),
    ("preflight.yml",          "templates/github/preflight.yml",          False),
]

BACKTICK = chr(96)  # built, not typed literally: a literal backtick here is
                     # odd-numbered and this heredoc sits inside `<( ... )`,
                     # where bash's parser tracks backtick pairing even
                     # though the 'PY' delimiter makes the content literal
TOKENS = re.findall(BACKTICK + r"([^" + BACKTICK + r"]*)" + BACKTICK, skill)

for dest, src_rel, is_tmpl in WORKFLOWS:
    src_abs = os.path.join(kit, src_rel)
    problems = []
    if not os.path.isfile(src_abs):
        problems.append("source missing on disk")

    # `dest` is cited either bare (step 10: `claude.yml`) or path-prefixed
    # (step 11: `.github/workflows/gates.yml`) -- collect every exact-token
    # occurrence, then require src_rel in the token immediately following
    # at least one of them. A substring test on the raw text is not enough:
    # dest is also the tail of every sibling source path (".../gates.yml"
    # contains "gates.yml"), so it would count a neighbor's citation too.
    dest_positions = [i for i, tok in enumerate(TOKENS)
                       if tok == dest or tok == f".github/workflows/{dest}"]
    if not dest_positions:
        problems.append(f"SKILL.md never names {dest!r} as a copy destination")
    else:
        cited_next = [TOKENS[i + 1] for i in dest_positions if i + 1 < len(TOKENS)]
        if not any(src_rel in tok for tok in cited_next):
            found = cited_next[0] if cited_next else "(nothing)"
            problems.append(f"SKILL.md names {dest!r} but cites {found!r} next, not {src_rel!r}")

    if is_tmpl and os.path.isfile(src_abs):
        try:
            rendered = re.sub(r"\{\{[A-Z_]+\}\}", "dummy", open(src_abs).read())
            yaml.safe_load(rendered)
        except Exception as e:
            problems.append(f"does not render to valid YAML: {e}")
    label = f".github/workflows/{dest} <- {src_rel}"
    if problems:
        print("FAIL " + label + ": " + "; ".join(problems))
    else:
        print("PASS " + label)
PY
)

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
