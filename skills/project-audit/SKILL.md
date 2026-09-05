---
name: project-audit
description: Audit an existing repo against the dev-kit framework and report what is missing, drifted, or misconfigured — rules, hooks, verify command, CI, seed quality, adapter coverage. Writes the full report to docs/dev-audit-<date>.md in the audited repo — findings, proposed changes with benefits and dangers, and a prioritized todo list. Use when the user asks to "rightsize", "audit", "check this repo", "why does Claude keep getting this wrong here", or before adopting an inherited codebase. Also use periodically on projects already scaffolded, to catch drift.
---

# Project Audit

Read-only, with exactly one exception: the audit report document this skill
exists to produce (see Output). Everything else — report, then ask before
changing anything.

## FRAMEWORK-absent mode

Determine first whether the repo carries the kit at all (`.claude/.framework-state.json`,
kit rules modules). When it does not — an unscaffolded or inherited repo — do not
improvise which checks translate:

- **Discover the repo's actual instruction layer first.** Find and read what
  exists: `CLAUDE.md` / `.claude/CLAUDE.md` / `CLAUDE.local.md`, `.claude/rules/`,
  `AGENTS.md`, `CONTRIBUTING`, process docs. For each stated rule, classify it:
  actually enforced (their CI, tests, hooks) vs enforceable-but-prose. That list
  is the enforcement finding — and the mature local equivalents it reveals are
  exactly what the Adoption recommendation must respect. A guide in a file that
  does not auto-load (`AGENTS.md` without a `CLAUDE.md` importing it) is the
  headline finding, not a skipped check.
- **Run as-is:** config presence, verify integrity, rules-vs-reality (judged
  against the rules discovered above), and the code-level spot checks.
- **Statelessness (if multi-instance):** the target has no gate script of its
  own — run the **plugin's** copy from the target's root:
  `python3 "$CLAUDE_PLUGIN_ROOT/scripts/check_statelessness.py"`. The unwired
  gate in the target is itself a finding; a missing-file error is not.
- **Skipped by construction — declare each in *Not checked*:** framework
  version/drift classification, registry honesty against the kit registry, and
  the kit gate scripts the repo never wired. Absence of a baseline is a fact to
  state, never a gap to silently skip past.
- **Org checks** run if a profile exists at `~/.claude/f4d/orgs/`; if none exists,
  say so and **recommend** `/org-profile` — never run it mid-audit (it is
  interactive and writes global state; the audit's only write is the report).
  Company identity (GitHub org, domains, agency vs own-product) is what these
  checks exist to verify.

## Checks

**Org alignment**
- Is there an org profile for this project's company at `~/.claude/f4d/orgs/`? If not, report that and recommend `/org-profile` — do not run it mid-audit.
- Does `.claude/rules/org.md` exist and match the profile's current `constraints` block? Report drift in either direction.
- Do this repo's conventions match the org profile — webhook prefix, package scope, env prefix, default branch?
- Is this repo on the org Project board if the profile says `coherence: shared`?

**Config presence**
- `CLAUDE.md` exists, is under 80 lines, has no unfilled `{{TOKEN}}`
- `.claude/rules/` exists and the modules match what the project actually does
- `.claude/settings.json` wires the guard hook
- `.gitignore` covers `.env`, `*.key`, `*.pem`

**Evidence first — run this before forming any opinion**

```bash
python3 "$CLAUDE_PLUGIN_ROOT/scripts/session_report.py"
```

It reports counts, not recollection: how many sessions started outside the repo
root (a relative-path risk signal — `CLAUDE.md` and unscoped `.claude/rules/`
load there regardless), how often verify actually ran, and whether the rules set
changed mid-window. Subdirectory starts do **not** invalidate rule conclusions —
every session in that log ran the hook that wrote it, and current Claude Code
auto-loads the instruction layer with an upward walk. Only independently
observed missing rule context (e.g. `/context` showing no memory files) warrants
a load-path remediation.

If there is no log yet, do not wait for one. Say so, and fall back to the static
checks below — they are available immediately.

**Enforcement layer** — check this before anything else
- Is `SessionStart` wired in `.claude/settings.json`? (Doctrine corrected twice, 2026-08-11 — current truth per the Claude Code memory docs: `CLAUDE.md` auto-loads with an upward walk AND unscoped `.claude/rules/*.md` auto-load at launch. On current CLI versions the hook is **not** what puts rules in context; treat its absence as losing **session-START records specifically** — the per-session denominator for rates. Deny fire counts still accrue independently (`guard.sh`/`rule-zero.sh` write `.claude/.enforcement-log` regardless), and `verify-record.sh` still writes verify entries to `.session-log`. (A15 decided: session-start telemetry is this hook's primary job; loading is automatic on current CLIs, verified empirically on 2.1.220.)) Verify actual loading with `/context`, not inference.
- Are `rule-zero.sh` and `done-check.sh` wired?
- Is `.claude/hooks/guard-local.sh` present, executable, and wired (A11)? Without it, uninstalling the plugin silently removes every guard — the fallback is the floor that survives.
- Are the implied `.claude/agents/*.md` files actually present — `verify-runner` unconditionally, plus `schema-reviewer` / `integration-auditor` / `contract-drift-checker` for each of `database` / `data-integration` / `contracts` held in `.claude/rules/` (A20 — the A11 shape one layer up, for agents instead of hooks)? Run `python3 "$CLAUDE_PLUGIN_ROOT/scripts/check_agents.py"` from the target's root: `SKIP` means this repo has not adopted the kit (not a finding); a `VIOLATIONS` result names exactly which file is missing or empty and which held module implied it. A module implying an agent with no corresponding file means that advisory review has been silently not running, possibly for months.
- Is the plugin installed **at the version `.claude/.framework-state.json` records**? A missing plugin means every `${CLAUDE_PLUGIN_ROOT}` hook has vanished; a version mismatch means the hooks running are not the hooks the project was scaffolded against.
- For each rule in `.claude/rules/`, ask: is this mechanically enforceable, and is it enforced? List every enforceable-but-prose rule. That list is the real audit finding.
- Are there near-duplicate files suggesting Rule 0 was not in force — `*V2`, `*-final`, `*-new`, `*-copy`, `*-updated`?

**Framework version**
- Read `.claude/.framework-state.json`. How far behind is this repo?
- Run `python3 "$CLAUDE_PLUGIN_ROOT/scripts/upgrade.py" --plugin "$CLAUDE_PLUGIN_ROOT"` and report the classification counts.
- **Confirm the plugin is actually installed.** Every hook path is `${CLAUDE_PLUGIN_ROOT}/...`; if the plugin is absent, every guard has silently disappeared and the repo looks fine. Absence reads as permission — the same failure shape as a guard that cannot parse its input.
- **Check declared companions.** Run `python3 "$CLAUDE_PLUGIN_ROOT/scripts/check_companions.py"` from the target's root. A declaration in `.claude/.framework-state.json` that the host does not satisfy is a finding (G-06): every rule the project stopped stating because a companion covered it is now enforced by nothing. A `SKIP` result means this host has no plugin registry — report it as not-checked, never as a pass. Likewise, `OK — no companion plugins declared` is not a pass in any meaningful sense — it means there is nothing to verify, not that the project was reviewed and found to need none; treat it as the trigger for the recommendation below, never as a clean bill of health.
- More than two minor versions behind → upgrade before any new feature work.

**Registry honesty** — the highest-signal check in this audit
- Does `.claude/rules/manifest.json` exist? Validate it:
  `python3 "$CLAUDE_PLUGIN_ROOT/scripts/render_registry.py" --validate` — **an unknown ID fails the audit** (A9: IDs are permanent; a broken reference means the manifest or plugin version is wrong).
- A committed `.claude/rules/REGISTRY.md` is itself a finding: projects render from the manifest now (A2); a copy is stale by definition. `upgrade.py` flags it as `STALE-REGISTRY`.
- Render the view (`render_registry.py`) and then, for every held row claiming `HOOK`, `TEST`, or `GATE` — overrides included: **confirm that check actually exists and runs.** A manifest asserting enforcement that is not wired is worse than none — it makes the gap invisible.
- For every held row marked `PROSE` with a promote-when trigger: has the trigger fired? List those. That list is the promotion backlog.
- Run each gate script directly and report pass/fail:
  `python3 node_modules/@roofadvisor/dev-kit/scripts/check_fixtures.py`, `check_contract_pin.py`, `check_guess_lists.py` — from the pinned devDependency (ADR 005), never from a copy
- A `.github/scripts/check_*.py` still present is a finding: since 2.2.0 the kit is a dependency and `gates.yml` fails while copies remain (framework-upgrade: *Kit as a devDependency (2.2.0)*). So is a `package.json` whose verify or CI runs a design or registry gate with no `@roofadvisor/dev-kit` in `devDependencies`.

**Verify integrity**
- A single verify command exists
- It is identical in CLAUDE.md, the script, and CI
- It passes right now — run it

**Rules vs reality** — the highest-value section
- Does the repo have integrations but no `data-integration.md`?
- Object storage but no `storage.md`?
- Money math but no `money.md`?
- Production traffic but no `livesystem.md`?
- Conversely: any module present for something the repo does not do? Remove it — dead rules cost context on every turn.

**Statelessness** — only meaningful for multi-instance projects; check first whether it is one
- Run `python3 node_modules/@roofadvisor/dev-kit/scripts/check_statelessness.py`
- Does the local stack run **two** instances? If it runs one, every ST-* bug in this repo is currently invisible and no amount of testing will surface it.
- Do migrations run at app boot? That is a deploy-time race, not a startup convenience.
- Is there at least one test that writes on one instance and reads on another?
- Any `stateless-ok` annotation without a reason after it
- Every `stateless-ok import-time registration` annotation: **re-verify the claim** — re-grep the register function's call sites; any non-top-level or handler-reachable call site (including a lazy/dynamic import of the registering module) invalidates the annotation. Report it; never trust an annotation whose evidence no longer holds. This re-verification is the audit's job, not the user's.

**Design** — only meaningful when the project has design capability. Check
**both** signals, either is sufficient — do not gate on the declaration
alone: `.claude/.framework-state.json` declares a design bundle (`bundles`
non-empty — the `/project-init` interview path), **or** any of
`design-tokens.md` / `design-a11y.md` / `design-components.md` /
`design-handoff.md` exists in `.claude/rules/` (the migration path —
`framework-upgrade`'s named `frontend` → design-modules migration copies
these modules in without ever recording `bundles`; `grep -c bundles
skills/framework-upgrade/SKILL.md` returns 0). Gating on the declaration
alone would silently skip this entire section — including the finding that
would catch a bundle's gate never having been wired — on every repo that
took the migration path instead of a fresh `/project-init`.
- **Design bundles declared but unwired.** Not every bundle adds a module —
  `design.content`, `design.direction`, and `design.govern` resolve to none by
  design (`${CLAUDE_PLUGIN_ROOT}/skills/project-init/references/module-catalog.md` § *Design
  modules* has the mapping). For the three that do —
  `design.tokens`→`design-tokens`, `design.verify`→`design-a11y`,
  `design.build`→`design-components`+`design-handoff` — a bundle whose rules
  module is absent from `.claude/rules/`, or whose gate is missing from the
  verify command, is a finding. A declared capability nothing runs is a
  finding, not a pass.
- **Playwright unresolvable.** Run
  `node "$CLAUDE_PLUGIN_ROOT/kit/scripts/measure_render.mjs" "$CLAUDE_PLUGIN_ROOT/kit/examples/sample-app/preview.html"`
  — an explicit, plugin-owned fixture, not `--help` (undocumented by the
  script itself; with no file argument it silently falls back to scanning
  this repo's own `examples/`, which may or may not exist in the audited repo
  and proves nothing either way). A "playwright not installed" line means
  every render gate in this repo is reporting SKIPPED. Report it as an
  environment finding — a skipped gate is never a passed gate.
- **Stale plugin namespaces.** `grep -rnE "(f4d-kit|design-kit):" CLAUDE.md
  AGENTS.md .claude/rules/ .cursor/rules/ 2>/dev/null | grep -vE
  "(f4d-kit|design-kit):rules([^a-zA-Z0-9_-]|$)"`. Both retired at dev-kit
  2.0.0; a stale prefix names a skill that no longer resolves. Scans all
  three files `render_instructions.py` writes to (`CLAUDE.md`, `AGENTS.md`,
  `.cursor/rules/dev-kit.mdc` — the last lives under `.cursor/rules/`, not
  `.claude/rules/`) plus the project's own rule modules. The second grep
  excludes `render_instructions.py`'s own `f4d-kit:rules` /
  `design-kit:rules` block-sentinel markers (the `BEGIN`/`END` comments
  around the generated rules index — a block name, never a skill reference)
  so the sentinel itself stops reporting as a finding; a genuine stale
  reference such as `f4d-kit:project-init` still matches the first grep and
  is untouched by the second, since `project-init` is not `rules`. Do not
  rename the sentinel to "fix" this — every already-scaffolded repo carries
  the old `f4d-kit:rules` marker in committed files, and renaming it makes
  the renderer append a second block instead of replacing the first.

**Code-level spot checks**
- Any test that calls a live external API
- Any `float` in a currency path
- Any FK without an index
- Any outbound call without a timeout
- Any log line that could emit a payload or credential
- Seed data: does it contain nulls, unicode, and boundary values, or only happy-path rows?
- Any `catch` returning an empty collection — then grep that collection's consumers for **counts and comparisons**, not just renderers
- Any test iterating a collection without first asserting it is non-empty (vacuous pass)
- Any raw identifier reaching user-visible output
- Any hardcoded list of values the source could report live (guess list), and whether two such lists exist for the same question

## Output

First print the summary:

```
REPO:       <name>
FRAMEWORK:  present | partial | absent
VERIFY:     PASS | FAIL | MISSING

MISSING     (should exist, does not)
DRIFTED     (exists, disagrees with itself or with the code)
UNNEEDED    (present, project does not need it)
FINDINGS    (code-level, with file:line)
```

Then write the full report as **`docs/dev-audit-<YYYY-MM-DD>.md`** in the audited
repo — on a dedicated branch when the repo has git, never pushed unasked. **This
document is the only file the audit writes.** Sections, in order:

1. **Header** — repo, date, kit version audited against, framework presence, verify status.
2. **Summary** — three sentences max: what will bite soonest and why.
3. **Findings** — the four categories above. Evidence per entry: `file:line`
   where a line exists; for absence and external-state findings (a missing
   `CLAUDE.md`, an uninstalled plugin, an unversioned service) cite the
   observable that proves it — a directory listing, command output, or the
   external system's state. Never omit a finding for lack of a line, and never
   invent a location to satisfy the format.
4. **Proposed changes** — one row per change: what | benefit | danger | effort (S/M/L),
   ranked by what bites soonest. The **danger** column is not optional and "none" is
   rarely true: name what adopting the change could break in *this* repo — a hook that
   would start blocking a current workflow, a gate that goes red on existing code, a
   verify command that fails on the baseline. A gate that fires wrongly gets disabled,
   and a disabled gate protects nothing — so the danger column is where that fate is
   predicted and avoided.
5. **Todo list** — prioritized checkboxes, one per proposed change, each self-contained
   enough to hand to a fresh session.
6. **Not checked** — what this audit could not evaluate and why. Silence reads as
   "checked and fine"; say what wasn't.
7. **Adoption recommendation** — *required when FRAMEWORK is absent or partial.*
   The specific slice of the kit this repo should adopt first (usually the
   enforcement layer: load path, `SessionStart`, secrets guard, one canonical
   guide), and — just as explicitly — what it should **not** adopt because a
   mature local equivalent exists; local customizations survive, the framework
   is never taken wholesale. Name the next step (`/project-init --plan` in
   RETROFIT). The recommendation is advice with dangers attached, not a queued
   action: merging the report adopts nothing.

   When the repo declares no companions, say so and consider recommending `superpowers` (MIT, multi-harness) as a **suggested add, never an assumed one**. It supplies process skills — TDD, planning, systematic debugging, code review — that the kit currently restates in prose. **Danger:** it wires its own `SessionStart` hook and adds roughly 3 KB of always-on context plus fourteen skill descriptions, against the ~400-line rules budget (§7.8); and adopting it without a G-06 declaration recreates A11 one level up. Recommend the declaration and the plugin together, or neither.

Rank everything by what will bite soonest. Then ask: *"Want me to fix these, or start with the top three?"* Never fix unasked — the report document is the deliverable; applying it is a separate decision.

**No in-progress markers may survive into the committed report.** Before
committing, scan the document for pending/placeholder sentinels ("in progress",
"recorded once … completes", "TBD") — finish them or remove them. A report that
ships both a result and a placeholder for that result publishes two truths.
