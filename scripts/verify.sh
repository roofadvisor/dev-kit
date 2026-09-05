#!/usr/bin/env bash
# The kit's single verify command.
#
# /project-audit demands one of every project it audits ("A single verify
# command exists; it is identical in CLAUDE.md, the script, and CI; it passes
# right now"). The kit had none — five harness invocations and a handful of gate
# scripts, listed in START_HERE.md and duplicated in two workflows, with nothing
# tying them together.
#
# That gap was not cosmetic. hooks/verify-record.sh records a verify run only
# when the command matches *verify*|*pytest*|*vitest*|*forge test*|*npm test*|
# *pnpm test*, and `bash tests/hooks_test.sh` matches none of them. So the kit
# could never record a verify run against itself, and hooks/done-check.sh —
# which blocks Stop when source changed and no verify was recorded — would have
# blocked every single session here the moment the hooks were armed.
#
# Named `verify.sh` deliberately: it matches the *verify* pattern, so running it
# is what makes done-check.sh satisfiable in this repo.
#
# Exit 0 only when everything passes. Any failure is loud and fatal.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$KIT"

fail=0
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

section "harnesses"
total=0
for t in hooks render_registry render_instructions gate_trio statelessness conformance companions scanner_agreement agent_presence notion_sync token_build release; do
  # Harnesses are self-contained fixtures — gate_trio_test.sh in particular
  # asserts BOTH check_commits/check_test_count behaviors, "BASE_REF set" and
  # "BASE_REF unset", inside its own disposable repos. CI never leaks BASE_REF
  # into them because the harnesses job and the gates job run on separate
  # runners. verify.sh runs everything in one process, so once BASE_REF is
  # honored below, a caller who exports it (exactly what this script now asks
  # people to do) would otherwise bleed it into these subshells and flip their
  # "unset" assertions — a self-inflicted false FAILED unrelated to the PR
  # being checked. Unset it explicitly for this loop only.
  line=$(env -u BASE_REF bash "tests/${t}_test.sh" 2>&1 | tail -1)
  n=$(printf '%s' "$line" | grep -o 'pass=[0-9]*' | cut -d= -f2)
  f=$(printf '%s' "$line" | grep -o 'fail=[0-9]*' | cut -d= -f2)
  # A harness that printed no counts did not run to completion — that is a
  # failure, not a zero. Absence reads as permission otherwise.
  if [ -z "${n:-}" ] || [ -z "${f:-}" ]; then
    printf '  %-20s NO COUNTS — harness did not complete\n' "$t"
    fail=1
    continue
  fi
  total=$((total + n))
  [ "$f" -eq 0 ] || fail=1
  printf '  %-20s %s\n' "$t" "$line"
done
printf '  %-20s %s assertions\n' "(total)" "$total"

section "gate scripts"
for g in check_statelessness check_guess_lists check_catch_empty check_log_hygiene \
         check_companions check_raw_sql check_pure_imports check_contract_pin \
         check_fixtures check_rollback check_agents check_instruction_honesty; do
  if python3 "scripts/${g}.py" >/dev/null 2>&1; then
    printf '  %-24s clean\n' "$g"
  else
    printf '  %-24s FINDINGS\n' "$g"
    fail=1
  fi
done

# check_commits and check_test_count need BASE_REF and are meaningless without a
# base to compare against. gates.yml always sets it (BASE_REF=origin/<base
# branch>) and runs both unconditionally against it — verify.sh must do the
# same whenever a caller (CI, or a person who exports BASE_REF locally) has it
# in the environment, or a local "VERIFY PASSED" does not mean what CI's
# PASSED means (a branch that deletes tests or has a malformed commit subject
# could report clean here and fail in gates.yml on the same commit). Only when
# BASE_REF is genuinely absent — no base to diff against — do we skip, and the
# skip is printed rather than silent.
if [ -n "${BASE_REF:-}" ]; then
  section "base-ref gates (BASE_REF=$BASE_REF)"
  for g in check_commits check_test_count; do
    if python3 "scripts/${g}.py" >/dev/null 2>&1; then
      printf '  %-24s clean\n' "$g"
    else
      printf '  %-24s FINDINGS\n' "$g"
      fail=1
    fi
  done
else
  section "skipped locally (need BASE_REF — CI runs these)"
  printf '  %-24s %s\n' "check_commits" "C-06"
  printf '  %-24s %s\n' "check_test_count" "C-08"
fi

# Design gate — only when the project carries design rules. verify.sh is named
# to match verify-record.sh's pattern, so running it is what makes done-check
# satisfiable; the design gate belongs inside it for the same reason.
#
# Guards on $KIT, not a bare $ROOT: this script's own root variable is $KIT
# (set above, from dirname "$0"), and set -u turns any reference to an unset
# $ROOT into an immediate hard crash of the whole script — guard condition
# false or true, design repo or not. Confirmed by hand: a plain
# `[ -f "$ROOT/x" ]` under `set -uo pipefail` aborts with "ROOT: unbound
# variable" before the `[` ever runs. A guard that cannot evaluate cleanly on
# every caller is the opposite of "skips cleanly."
#
# This block is permanently dark IN THIS REPO, by construction: the plugin's
# own tree never carries .claude/rules/design-tokens.md (the plugin is not
# itself a scaffolded design product). Nor does it matter for a scaffolded
# project either way — nothing copies verify.sh into one, so this exact file
# never runs there. That is not this block's job — it stayed here only as
# the pattern a copied verify.sh would follow if one ever existed. The
# automatic path that actually matters lives one level down:
# skills/project-init/references/scaffold-spec.md's "Verify command by
# stack" table appends the same accuracy_report.mjs invocation — guarded not
# on a rules file but on actually locating the plugin (prefer
# $CLAUDE_PLUGIN_ROOT when set, else resolve it from Claude Code's own
# ~/.claude/plugins/installed_plugins.json registry, since a scaffolded
# project's OWN verify script and CLAUDE.md are what carry it, run from a
# plain shell with no plugin-hook-scoped variable to lean on) — to every
# project that actually selects a design bundle — so a real design project's
# verify command, not this one, is where the gate genuinely fires.
if [ -f "$KIT/.claude/rules/design-tokens.md" ]; then
  section "design gate"
  if node "${CLAUDE_PLUGIN_ROOT:-$KIT}/kit/scripts/accuracy_report.mjs"; then
    printf '  %-24s clean\n' "accuracy_report"
  else
    printf '  %-24s FAILURES ABOVE\n' "accuracy_report"
    fail=1
  fi
fi

section "result"
if [ "$fail" -eq 0 ]; then
  echo "  VERIFY PASSED"
else
  echo "  VERIFY FAILED"
fi
exit "$fail"
