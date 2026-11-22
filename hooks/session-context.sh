#!/usr/bin/env bash
# SessionStart hook. A15 DECIDED 2026-08-11 — re-scoped, kept:
#
#   PRIMARY JOB: session telemetry. This hook writes .claude/.session-log —
#   the evidence session_report.py, /retro, and /promote-rule run on. Retiring
#   it retires the evidence.
#   SECONDARY: a one-line-per-file index of .claude/rules/ and the ENFORCEMENT
#   note. The rules auto-load (proven on Claude Code 2.1.220: a sentinel rule in
#   .claude/rules/ loaded headlessly with NO hook and no settings.json); the
#   index is kept for older CLIs and --setting-sources exclusions.
#
# 2.5.0 (owner ruling 2026-11-22): it no longer prints CLAUDE.md. Claude Code
# loads CLAUDE.md itself, from the cwd and every folder above it, so the copy
# printed here was the same file a second time, in every session's context. And
# it was sometimes the wrong file: the hook process starts where the session
# launched, so in a worktree session it printed the main checkout's CLAUDE.md,
# which can be days behind the worktree's own. Everything below now reads the
# session's own tree (the payload's cwd, hook_enter_session_dir), as done-check
# and verify-record already do.
#
# AGENTS.md-style guides still never auto-load; the documented fix there is an
# @AGENTS.md import in CLAUDE.md, not this hook.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_parse.sh"
input=$(hook_read_input)
hook_enter_session_dir "$input"
hook_opted_in || exit 0

# `git rev-parse --show-toplevel` returns the PHYSICAL path, with symlinks resolved.
# `pwd` returns the LOGICAL one, preserving whatever spelling the shell was cd'd
# through. Compare the two and they never match under a symlink — the root/subdir
# test below reports "subdir" while standing at the root, and the prefix strip
# silently fails, writing the whole absolute path into the relative-path field.
# Measured on macOS, where mktemp -d hands back /var/folders/... and /var is a
# symlink to /private/var; equally reachable through any symlinked repo path.
# `pwd -P` makes both sides physical.
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cwd=$(pwd -P)

echo "=== PROJECT RULES (injected — cwd is $cwd) ==="

if [ "$cwd" != "$root" ]; then
  echo "NOTE: this session did not start at the repo root ($root)."
fi

if [ -d "$root/.claude/rules" ]; then
  echo "--- .claude/rules/ (read the relevant file before working in that area) ---"
  for f in "$root"/.claude/rules/*.md; do
    [ -e "$f" ] || continue
    echo "  $(basename "$f") — $(head -3 "$f" | grep -v '^#' | grep -v '^$' | head -1)"
  done
fi

# Enforcement reminder. The point is that prose is ignorable and hooks are not.
cat <<'EOF'
--- ENFORCEMENT ---
Hooks execute; they are not advisory. If a hook blocks you, the answer is to
change the approach, never to work around the hook.
Rules in .claude/rules/ are prose and therefore ignorable — which is exactly why
anything load-bearing should have become a hook or a test. If you find yourself
relying on a prose rule to prevent something expensive, say so: that rule is
mis-classified and belongs in .claude/hooks/ or the test suite.
EOF
# ── Telemetry ────────────────────────────────────────────────────────────
# "Observe for a week" is not something an agent can do — every session starts
# blank. So the observation is written down instead of remembered.
# /project-audit reads this log and reports on real counts, not recollection.
log="$root/.claude/.session-log"
mkdir -p "$(dirname "$log")" 2>/dev/null
{
  printf '%s\t' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s\t' "$([ "$cwd" = "$root" ] && echo "root" || echo "subdir")"
  printf '%s\t' "$(printf '%s' "${cwd#$root}" | sed 's|^/||' | cut -c1-40)"
  printf '%s\t' "$([ -f "$root/CLAUDE.md" ] && echo "claudemd" || echo "no-claudemd")"
  printf '%s\n' "$(ls "$root/.claude/rules"/*.md 2>/dev/null | wc -l | tr -d ' ')rules"
} >> "$log" 2>/dev/null

echo "=== END PROJECT RULES ==="
exit 0
