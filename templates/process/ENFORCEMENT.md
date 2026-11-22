# Enforcement

The organizing principle of this framework, and the one it most easily violates.

## Three layers, differing in whether they can be ignored

| Layer | Enforced by | Ignorable? |
|---|---|---|
| **Hooks** (plugin-declared `hooks/hooks.json`, plus `.claude/settings.json` for the local fallback) | The harness, before/after tool calls | **No** — it executes |
| **Tests** (verify, CI) | The test runner | **No** — it fails the build |
| **Skills** | Fire on task shape | Only by not invoking them |
| **Instruction files** (CLAUDE.md, rules) | Being read | **Yes — demonstrably** |

Anything load-bearing should be a hook or a test. Instruction files carry
reference and judgment, not enforcement.

**Why most hooks are not in this repo's own `.claude/settings.json` (A18).**
`${CLAUDE_PLUGIN_ROOT}` — needed to point a hook command at code that lives in
the plugin — only resolves inside the plugin's *own* `hooks/hooks.json`. Built
into a project's own `settings.json` instead, it silently fails: the hook is
skipped, not run with an empty value (measured on Claude Code 2.1.220). So this
project's guard, rule-zero, done-check, format, verify-record, and
session-context hooks are declared once, globally, by the plugin — which means
they match on *every* repo you have Claude Code open in, not only this one.
Each checks `.claude/.framework-state.json` before doing anything else and
no-ops instantly if it is absent, which is how a repo that never adopted this
framework pays nothing for a plugin it may not even have installed. The one
hook still wired directly in this repo's `settings.json` is
`.claude/hooks/guard-local.sh` — copied in at scaffold time specifically so a
relative path works, and specifically so C-01/C-02 still block if the plugin
itself is ever uninstalled.

## The load path

*(Corrected twice on 2026-08-11 — first the subdirectory claim, then the rules
claim, both against live evidence and the Claude Code memory docs. Recording
both corrections because each earlier version taught a live audit a false
finding.)*

What current Claude Code auto-loads, per its memory documentation:

- `CLAUDE.md` / `CLAUDE.local.md` — **upward walk** from the session's working
  directory; a root file reaches a session started in `dist/` or `packages/x/`.
- `.claude/rules/*.md` — discovered **recursively and loaded at launch** when
  unscoped ("the same priority as `.claude/CLAUDE.md`"); rules with `paths:`
  frontmatter load on demand when matching files are read. Symlinked rules
  resolve normally.

What does **not** auto-load: `AGENTS.md`-style guides. The documented fix is a
`CLAUDE.md` that imports it (`@AGENTS.md`) or a symlink — not a hook.

**Where that leaves `hooks/session-context.sh`:** A15 decided 2026-08-11,
with evidence — on Claude Code 2.1.220 a sentinel rule in `.claude/rules/`
loaded headlessly with no hook and no `settings.json`. The hook is re-scoped:
its **primary job is session telemetry** (`.claude/.session-log`, the evidence
layer for `session_report.py`, `/retro`, `/promote-rule`); the rules-index
injection is redundant defense-in-depth kept for older CLIs and
`--setting-sources` exclusions. Since 2.5.0 it no longer prints CLAUDE.md
(Claude Code loads it, and in a worktree session the hook's copy was the main
checkout's), and it reads the session's own worktree. Do not cite it as
the reason rules are in context, and verify actual loading with `/context`
rather than inference. "The agent stopped reading the rules file" can still be
a configuration defect — but establish it with evidence, not doctrine.

Corollary: **never diagnose a repeated instruction failure as inattention until
you have confirmed the instruction was actually in context.** Check the load path
first.

## Hook precedence (A6 — evidence-backed)

When multiple hooks match one tool call — two `PreToolUse` entries on `Write`,
or plugin hooks alongside a project's own — the contract is:

- **All matching hooks run — observed directly via per-hook markers, both
  orders — and any hook exiting 2 blocks the call.** A passing hook cannot
  override a blocking one, and a blocking hook does not prevent later hooks
  from running (so side-effectful hooks still fire on blocked calls — design
  them accordingly).
- **Order affects only which message the user sees first, never correctness.**
  Proven both ways on CLI 2.1.220 with a validity control
  (`docs/acceptance/2026-08-11-a6-hook-precedence.md`).
- Plugin and project hook arrays **merge** (per the settings documentation);
  writing a project hook never disables a plugin hook on the same matcher.

Design consequence: hooks must be independent — never write a hook that
assumes another hook ran before it, and never rely on ordering to suppress a
block.

## Honest audit of this framework

Most of what dev-kit ships is prose, and prose is the ignorable layer. Where each
rules module actually sits:

| Module | Mechanically enforceable | Currently enforced by |
|---|---|---|
| `keysafety` | Yes | **hook** — `guard.sh`, exit 2 |
| `core` (no force-push, no destructive SQL) | Yes | **hook** — `guard.sh` |
| Canonical home / no duplicate variants | Yes | **hook** — `rule-zero.sh` |
| Done-without-verify | Yes | **hook** — `done-check.sh` |
| `database` (FK indexes, unsafe migrations) | Yes | `schema-reviewer` agent — advisory, should become a test |
| `data-integration` (timeouts, retries, fixtures) | Yes | `integration-auditor` agent — advisory, should become a test |
| `contracts` (drift) | Yes | `contract-drift-checker` agent + CI gate |
| `silent-degradation` (empty-collection, raw ids) | **Yes — and not yet enforced** | prose. Highest-value gap. |
| `capability-parity` (consumer enumeration, parity) | **Partly — and not yet enforced** | prose |
| `money` (splits sum, no float) | Yes | prose — should be a lint rule + property test |
| `determinism` (golden fixtures) | Yes | prose — should be a committed fixture test |
| `guards` (red-then-green) | Partly | prose + Definition of Done |
| `api`, `python`, `typescript` style | Partly | linter where possible, else prose |
| `livesystem`, `dataprotection`, `observability` | Mostly judgment | prose, correctly |

**The rightmost column is the roadmap.** Every "prose" entry that is mechanically
enforceable is a known gap, not an accepted state.

## Rules that should become tests, in priority order

These are the checks that catch silent degradation — the failure class that
survives review because the output still looks plausible:

1. **Non-empty assertion** — any test iterating a collection asserts it is non-empty first. An empty collection makes every assertion vacuously true.
2. **No raw ids rendered** — a test that fails if an identifier appears in user-visible output.
3. **Consumer enumeration** — changing a shared contract fails CI until every consumer is touched in the same change.
4. **Preview/execute parity** — a dry run and a live run produce the same request set.
5. **Row vs call failure** — one bad row in a batch does not abort the batch.
6. **Unconsumed capability is visible** — a capability with no consumer renders as disabled-with-reason, not as an absent control.
7. **One canonical resolver** — no two modules answer the same question from separate hardcoded lists.

Each needs a **failing-then-passing** test proving the harness works before it is
populated. A scaffold nobody has seen fail is the same defect one level up.

## The rule this page exists to prevent

> Every one of these rules was already in force, and none of them fired,
> because they are prose.

When `/retro` finds a rule that was violated, the first question is not "how do
we restate it" — it is **"which layer should this have been in?"**
