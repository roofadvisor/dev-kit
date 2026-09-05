# Changelog

## 2.2.0 — the kit is a dependency

Every design gate a project can run needs the plugin's `kit/`, and until now nothing
put it where a machine could find it without a human having installed Claude Code
first: the authoring gate ran by hand, three different resolvers answered "where is the
kit," and a bare CI runner was designed to print `SKIPPED`. The kit is now an installable
package.

Minor, not patch: tokens that never emitted before now do, and `project-init`'s output
changes.

- **`"@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#v2.2.0"`.** `package.json` is
  `@roofadvisor/dev-kit`; `files` ships `kit/`, `scripts/` and `.claude-plugin/` — about
  1 MB, not the 2.3 MB repository — and every gate runs from
  `node_modules/@roofadvisor/dev-kit`. A gate that needs the kit fails naming `npm ci`;
  it never skips. Release tags exist from `v2.0.0` on, so there is something to pin, and
  `ship-it` cuts the next one.
- **The registry gates come the same way.** `templates/github/gates.yml` runs
  `check_*.py` from `node_modules` after `npm ci`, and fails while `.github/scripts/`
  still holds copies — the scanners skip dot-directories, so a forgotten copy would drift
  in silence. Nothing is copied into a project any more.
- **Single-file token mode works, and is proven.** `project-init` used to say "seed
  `design-tokens.json` from `kit/tokens/`"; a literal merge built 70 of 320 variables
  after seven silent key collisions. The seed is generated
  (`kit/scripts/make_single_file_tokens.mjs`), committed at
  `templates/scaffold/design-tokens.json`, and `/gate` proves it builds at parity with
  the directory on every plugin change. A scaffolded project gets its **own** authoring
  gate — validity, contrast, `--strict`, hardcodes — not the plugin's self-check.
- **Four bugs the investigation found, fixed together.** 2.1.0's unmapped-group report
  claimed the colour tiers by bare name, so any file's top-level `semantic` read as
  covered — `spacing.semantic`'s 30 tokens hid behind it and now emit (`--space-stack-md`,
  `--space-page-inline-padding`, …). Both resolvers accepted a ref by dropping its first
  segment, which let `{dataviz.…}` pass for `data-viz.json`; a ref now resolves by its
  real path only, and the typo is fixed. `package.json`'s version had drifted from
  `plugin.json`'s; `tests/release_test.sh` fails when they disagree, and also when the
  plugin's own CI runs fewer harnesses than `verify.sh` — it ran seven of eleven. And a
  colour tier now covers only the leaves the colour emitter wrote: a `dimension` under
  `semantic` in `colors.json` used to vanish under `--strict` without a word.
- **Recorded and tested.** ADR 005 supersedes the scaffold-spec's two rationales —
  against vendoring, against a CI design job — as reasoning that was right for its
  premises. A consumer end-to-end job installs the kit on a bare runner from a git ref
  and runs the scaffolded gate, so the install path itself is under test.
- **C-06 admits `release`.** The commit gate had never run on this repository's own pull
  requests; the first time it did, it rejected `release:` — the type the three release
  commits before this one carry. The type is admitted, here and in every project that runs
  the gate from `node_modules`.
- **Templates hardened.** `gates.yml` reads the PR body through `env:` instead of
  splicing it into the script, installs with `npm ci --ignore-scripts`, and the
  scaffolded gate honours `KIT=` as the spec promised.

Upgrading a project: `framework-upgrade` → *kit as a devDependency (2.2.0)*. Upgrading
the plugin: `claude plugin update dev-kit@roofadvisor`.

## 2.1.1 — Rule 0 allows a plan beside its spec

One fix, found by using the plugin. `rule-zero.sh` blocked the first plan ever
written to the plugin's own convention: `writing-plans` puts a spec at
`docs/superpowers/specs/<x>-design.md` and its plan at
`docs/superpowers/plans/<x>.md`; the hook derives a concept from the plan's stem,
finds the spec repo-wide, and refuses. The merge's own pair predates the hook and
had never exercised it. The hook's message offered "state why a second file is the
right shape" — a step it provided no mechanism for.

- **A plan beside its spec is allowed.** A match whose basename is
  `<concept>-design.md` or `<concept>-spec.md` is the target's spec, not a
  variant, and is dropped. Every other match still blocks, including a `-v2` of
  the plan once the plan exists — three new harness cases, seen red first.
- **The message says what is actually sanctioned** instead of naming a step that
  does nothing.
- `package.json`'s version now matches `plugin.json`'s; it had said 2.0.0 since
  2.0.0. 2.2.0 makes that a test.

Upgrading is `claude plugin update dev-kit@roofadvisor`.

## 2.1.0 — the token builder stops discarding your tokens

Found by wiring a real project's tokens into its app rather than by reading the
code. `build_tokens.mjs` silently ignored any token group it did not recognise:
roof-club's base, product and operator systems each declared `font.line-height`,
the builder reads `font.leading`, and every line-height had been dropped from
every build since the tokens landed. No error, and nothing conspicuously absent
from the CSS to notice. A token you wrote and cannot use is worse than one you
never wrote, because you believe it is live.

Minor rather than patch: the fixes below cause tokens to emit that never emitted
before, so a project's generated CSS gains variables on upgrade.

- **Unmapped groups are now reported by name**, with the sibling groups the
  builder does read — a wrong key is nearly always a near miss, so
  `font.line-height` answers itself with *"this builder reads: font.family,
  font.size, font.weight, font.leading"*. It warns by default, so an upgrade
  cannot break an existing build; `--strict` makes it fatal, which is how a
  project's own token gate should run it.
- **Turned on, it found 62 dead tokens in this plugin's own token files**, so
  their fixes ship with it rather than a warning nobody could act on. DTCG
  gradient stop arrays (7) fell through to the shadow-layer branch and produced
  nothing — stops carry `position` and shadow layers never do, which is now what
  tells them apart. The `border` composite (4) had no shorthand. `states.*` (12),
  `data-viz.sequential` and `.diverging` (10), `typography.letterSpacing` (6) and
  `borders.width` (4) had no group entry at all. **324 light variables now, up
  from 286** — 38 tokens that were being authored and thrown away.
- **Three groups are excluded deliberately**, each recorded with its reason:
  `motion.keyframes` (from/to recipes — encode as `@keyframes`),
  `motion.reducedMotion` (a media-query concern), and `theming` (applied by
  selection, not flattened into `:root`). A check that cries wolf gets ignored,
  and is then worth nothing on the day it is right.
- **The builder had no tests**, despite generating every project's CSS.
  `tests/token_build_test.sh` adds 17, red-then-green, including that a shadow
  array does not regress into a gradient now that both are arrays of objects.
  Verify runs 389 assertions, up from 372.

One note recorded because it cost the first run: a group resolves either bare
(`font.size`, single-file layout) or stem-namespaced (`typography.fontSize`,
directory layout) depending on which candidate path matched. Checking a leaf
against one form only reported 62 false positives against this plugin's own
tokens — the same shape of bug as the one being fixed, two things that were never
speaking the same language.

Upgrading is `claude plugin update dev-kit@roofadvisor`.

## 2.0.1 — the guards stop firing on ordinary work

Seventeen fixes since 2.0.0, every one found by using the plugin rather than
reading it. No interface change: each narrows a check that was denying legitimate
work, or widens one that was missing a real leak.

- **C-01 rebuilt twice.** It first matched dotenv *filenames*, denying
  `process.env` and `os.environ` in every Node and Python command. The
  replacement matched reader *verbs*, and an adversarial review measured it
  against the rule it replaced: 65 commands newly allowed, only 4 of them
  intended. The other 61 were working leaks — `awk`, `python3 -c`,
  `curl -d @file`, `scp`, and `tac`, which is `cat` spelled backwards. It is an
  allowlist now: nine enumerated safe operations, deny by default, every command
  segment judged separately. A verb denylist that loses to reversing a word was
  never the mechanism.
- **Key material anchored.** Dictionary access denied as "key material is
  off-limits" because the extension was matched as a bare substring.
- **Shell control flow made transparent.** A loop that read only `.gitignore`
  denied, because a secrets filename appeared in it as a search pattern rather
  than a target. Keywords are now stripped and the real verb behind them judged,
  so a loop body that genuinely reads the file still denies.
- **Credential literals matched by issuer shape**, replacing a glob that denied
  the `sk-SK` locale and the npm lifecycle variables — the latter in every repo
  the plugin is installed in. Known issuers only; that limit is now stated in the
  code rather than implied.
- **Telemetry.** `verify-record.sh` truncated per line, so a multi-line command
  wrote one log line per input line — 91% of a real log was commit-message
  fragments, and `/retro` and `/project-audit` read that file.
  `session-context.sh` compared a logical `pwd` against a physical git root,
  mis-tagging every session reached through a symlink.
- **Broken references.** 17 skills cited a file at the wrong path; 131 catalog
  entries pointed into a directory this plugin deliberately does not ship, and
  now link to their real specs upstream at a pinned commit.
- **CI that had never run.** `main-verify.yml` watched `branches: [master]` in a
  repo whose default branch is `main`.

Upgrading is `claude plugin update dev-kit@roofadvisor`. Note that the updater
compares version strings, not commits — fixes pushed without a version bump do
not reach an installed copy, which is why this release exists.

## 2.0.0 — dev-kit: design-kit and f4d-kit merged into one plugin

`design-kit@roofadvisor` (the UX/UI design toolkit, 1.0.0) and `f4d-kit@f4d`
(the development framework, 1.23.8) are merged into a single plugin,
`dev-kit@roofadvisor`. One install now carries both halves — interview-driven
project scaffolding, composable rules modules, safety hooks, and audit agents,
alongside DTCG design tokens, component specs, and WCAG verification gates.
Design capability — the rules modules that load into every turn, and the
scaffolded `design-critic` agent — is opt-in per project, selected as one of
six bundles during `/project-init`'s Round 3, so a development-only project
carries none of it (see README).

**Three things that break a consumer:**

- Both old plugins must be uninstalled and `dev-kit` installed fresh — a
  plugin rename has no in-place upgrade path:
  ```bash
  claude plugin uninstall design-kit@roofadvisor
  claude plugin uninstall f4d-kit@f4d
  claude plugin marketplace add roofadvisor/dev-kit
  claude plugin install dev-kit@roofadvisor
  ```
- Every skill namespace changed: `f4d-kit:project-init` and `design-kit:gate`
  are now `dev-kit:project-init` and `dev-kit:gate`. Update any `CLAUDE.md`
  that names them by the old prefix; `/project-audit` reports stale prefixes
  it finds in an audited repo.
- `/scaffold-project` and `/ship` are removed. Their behaviour lives in
  `project-init` and `ship-it`, reached through the design bundles a project
  selects in Round 3 rather than through standalone commands.

**Known issues, disclosed rather than hidden:** this framework's own registry
treats a gate that fires wrongly as worse than no gate, so the two failures
below are named rather than suppressed. Neither is a regression introduced by
this merge — both predate it. Both are fixed here.

- **Fixed: `session-context.sh` wrote corrupt telemetry under any symlinked repo
  path.** It read the working directory with `pwd` (logical, preserving whatever
  spelling the shell was `cd`'d through) and compared it against
  `git rev-parse --show-toplevel` (physical, symlinks resolved). Under a symlink
  those never match, with two consequences: the prefix strip failed silently and
  wrote the entire absolute path into the relative-path field, and the
  root-versus-subdirectory test reported `subdir` while standing at the repo
  root. `/retro` and `/project-audit` both read that log. Now `pwd -P`, making
  both sides physical.

  This surfaced as a `tests/hooks_test.sh` failure that also occurs upstream, and
  was initially misdiagnosed — including in this changelog before release — as a
  macOS test artifact, on the grounds that `mktemp -d` returns a path under
  `/var/folders/...` where `/var` symlinks to `/private/var`. The test was right;
  the hook was wrong. It is fixed **without modifying the test**, which is the
  evidence: `bash tests/hooks_test.sh` goes from `pass=93 fail=1` to
  `pass=94 fail=0` on the hook change alone, and `bash scripts/verify.sh` now
  exits 0 with every gate clean.
- **Fixed: `measure_render.mjs` (the REAL-render WCAG gate) had no exemption
  for disabled controls, so it disagreed with its sibling `verify_states.mjs`
  about the same success criterion on the same element.** WCAG 2.2 SC 1.4.3
  exempts inactive UI components from contrast requirements, and `tabs.html`'s
  "Archived" tab correctly carries the `disabled` attribute
  (`kit/examples/component-states/tabs.html`). `verify_states.mjs` already
  encoded that exemption (`el.disabled || aria-disabled === 'true'` skips the
  element); `measure_render.mjs` walked every visible text node with no such
  check and scored the disabled tab's label as a live failure: **3.09:1**
  against the **4.5:1** AA requirement it does not, in fact, owe.

  This was initially misdiagnosed in this changelog — before release — as "a
  real WCAG AA contrast defect in the plugin's own bundled `tabs` component
  harness." The harness was correct; the gate was wrong. It is fixed by
  porting `verify_states.mjs`'s `isDisabled` check into `measure_render.mjs`,
  and the evidence is the gate rerun with Playwright and Chromium newly
  installed in this repo (`npm i -D playwright && npx playwright install
  chromium`): `node kit/scripts/accuracy_report.mjs` goes from **34/35** to
  **35/35** (100%), and `measure_render.mjs --dark` on every
  `component-states/*.html` harness — `tabs.html` included — passes.

**The design gate now has a real automatic path — say precisely what that
means.** This merge's own problem statement was that the design half "never
reaches the places that enforce anything": the gate (`accuracy_report.mjs`,
what `/gate` runs) previously fired only when a human or agent typed `/gate`
by hand, on no automatic path at all. `skills/project-init/references/scaffold-spec.md`'s
"Verify command by stack" table now appends a design-gate fragment whenever a
project selects a design module (`design-tokens` / `design-a11y` /
`design-components`), written identically into `CLAUDE.md`, the project's
`verify` script, and `.github/workflows/verify.yml`. The fragment resolves
the plugin's install location itself rather than treating
`${CLAUDE_PLUGIN_ROOT}` as an ordinary shell variable — outside a
plugin-declared hook it is not one, confirmed empirically (unset in a plain
Claude Code Bash tool call) — preferring it when a plugin-declared hook has
actually set it, and otherwise reading the install path straight out of
Claude Code's own `~/.claude/plugins/installed_plugins.json` registry, the
same file `claude plugin install` itself writes.

Precisely what "automatic" covers: the gate now runs for real every time a
scaffolded design project's own `verify` command runs from a shell where the
plugin is installed — a human or agent running `npm run verify` / `bash
verify.sh` locally, and automatically via `ship-it` step 1 — with no
Claude-specific environment required. It does **not** run on a bare GitHub
Actions runner: no plugin is installed there, so `templates/github/gates.yml`
still carries no design job (argued in that file) and the verify command's
design-gate segment prints `design gate: SKIPPED — …` and exits 0 rather than
failing on a precondition CI cannot meet — a skipped gate is disclosed as
exactly that, never as a pass. Read `GATE` anywhere in the rules registry
(`templates/rules/REGISTRY.md`) with that boundary in mind: real enforcement
wherever the plugin is present, an honest, non-blocking skip everywhere else.

Plugin identity: `dev-kit@roofadvisor` 2.0.0. Component inventory: 32 skills
(17 inherited from `design-kit`, 15 from `f4d-kit`), 2 commands, 5 agents,
4 hook events, ~3,423 always-on tokens on a clean-room install — see README
for the full breakdown.

## 1.23.8 — A23: this repo's own hooks anchored to ${CLAUDE_PROJECT_DIR}
A reviewer caught what PR #29 missed: repo-relative hook commands
(`hooks/x.sh`, shipped for this repo's own `.claude/settings.json`) only
resolve while the spawning shell's cwd **is** the repo root, and Claude Code
spawns every hook with cwd = wherever the session currently is. Confirmed live
on CLI 2.1.220: a `PreToolUse:Bash` hook wired with a bare relative path fired
once from root, then silently never fired again the moment the agent ran one
ordinary `cd` — the secrets guard, rule-zero, and done-check would all go dark
mid-session, no error, no log line. All six commands now anchor to
**`${CLAUDE_PROJECT_DIR}`** — a real env var Claude Code sets on every hook
process, distinct from `${CLAUDE_PLUGIN_ROOT}` (plugin-hooks-only; PR #29's
finding on that variable is unchanged) — and the anchored form was proven to
keep firing across the identical `cd` where the bare form went dark.

**Honest bound, not silently papered over:** anchoring does not fix a session
*launched* with cwd already inside a subdirectory — six live trials (both
path forms, one- and two-level-deep launches) show `.claude/settings.json` is
never discovered at all in that case, unlike `.claude/settings.local.json`,
which is documented to resolve through the repo root. No command-path fix can
help a file that's never read; tracked as **A23**, open. `tests/hooks_test.sh`
gains three cases reproducing the exact resolution mechanism `.claude/settings.json`
goes through (previous coverage invoked hooks via an absolute test-harness
path, sidestepping this). 43 → 46 hook tests, 147 → 150 total.

**Same-day review fix: the anchoring above shipped unquoted.** A reviewer on
this PR caught it before merge: `${CLAUDE_PROJECT_DIR}` is a real path that
can legitimately contain a space, an unquoted expansion word-splits in that
case, and Claude Code runs every hook command via `bash -c "$command"` — so
all six hooks would silently stop resolving (exit 127) on a project checked
out under a spaced path. Proven **fail-open**, not just asserted: per
`code.claude.com/docs/en/hooks.md`, exit 2 is the only exit code that blocks
`PreToolUse`/`Stop` hooks — a 127 is a non-blocking error and the tool call
proceeds. Demonstrated directly with `guard.sh`: a force-push command that the
quoted form correctly blocks (exit 2, BLOCKED) produces exit 127 and no
BLOCKED message at all through the unquoted form on a spaced path — the guard
never starts, so its own fail-loud (G-03) logic never gets a chance to run.
Fixed: every command now wraps the full expanded path in a literal quoted
pair (`"command": "\"${CLAUDE_PROJECT_DIR}/hooks/guard.sh\""`), verified via
`json.load` + `bash -c` end-to-end, not eyeballed. `tests/hooks_test.sh` gains
a spaced-project-directory fixture (red-then-green, plus a guard.sh
deny-survives-the-space hard-property case) and the existing generic
anchoring assertion now requires the quoted form. 46 → 50 hook tests,
150 → 154 total. Full evidence: `docs/BACKLOG.md` A23.

## 1.23.7 — A25: `verify.sh` now actually runs the checks it claimed to skip
Reviewer finding on an already-merged PR: `scripts/verify.sh` — the kit's one
advertised local verify command — printed "skipped locally (need BASE_REF —
CI runs these)" for `check_commits` (C-06) and `check_test_count` (C-08)
**unconditionally**, even when the caller (CI, or a person who exported
`BASE_REF` locally, exactly as intended) actually had it set. A branch with a
non-conventional commit subject, or one that deletes tests with no stated
reason, could report `VERIFY PASSED` locally while `gates.yml` correctly
failed the identical commit in CI — the two "verify" mechanisms diverged, and
the one this kit tells people to trust locally was the weaker one. If you run
`verify.sh` with `BASE_REF` set (matching CI's `BASE_REF=origin/<base
branch>`), it now runs both checks for real, the same invocation `gates.yml`
uses, and reports their actual pass/fail. No `BASE_REF` still skips, and the
skip is still printed, unchanged. Red-then-green proof, including a second
bug the proof surfaced (a caller's `BASE_REF` was leaking into the test
harnesses' own internal BASE_REF-set/unset assertions, now isolated), is in
`docs/acceptance/2026-08-13-a25-verify-sh-base-ref-gates.md`.

## 1.23.6 — A24: pin PyYAML instead of merely naming it
Reviewer finding on the already-merged PR #26, which added `pip install pyyaml` to `gates.yml` to fix a runner-image divergence against `main-verify.yml`: naming the dependency was right but incomplete. An unpinned `pip install pyyaml` still lets pip resolve whatever release is newest at install time, so a new PyYAML landing on PyPI between a PR's `gates.yml` run and the later `main-verify.yml` run on the merge commit could still change the conformance result on an otherwise-unchanged commit — the exact "green for a reason nothing in this repo controls" shape the original fix set out to remove, one layer down. Both workflows now pin the identical `pip install pyyaml==6.0.3`, plus the matching local-dev preflight message in `tests/conformance_test.sh`. No new lock/constraints file: verified this is the repo's only Python dependency (no `requirements.txt`/`constraints.txt`/`pyproject.toml` anywhere in the tree; every `scripts/*.py` imports only stdlib + `yaml`), so one would be disproportionate debt for a single package — two identical pinned lines, each with its own explanatory comment, instead. `conformance_test.sh` gained a same-pin assertion so a future edit that bumps one workflow's pin without the other fails CI instead of silently reopening this; red-then-green proven on that guard specifically (147 → 148 assertions). Proof for the pin itself is necessarily determinism, not red-then-green (a future PyPI release can't be forced to exist for a test): two independent `pip install pyyaml==6.0.3` runs in clean virtualenvs both resolved to `6.0.3`, and both workflow files grep to the byte-identical pin string.

## 1.23.5 — notion-sync templates: five review findings on the first real-world use

`templates/github/claude-code-review.yml`, `templates/github/notion-sync.yml`,
and `scripts/notion_sync.py` got their first outside review after being
copied byte-identical into three live RoofAdvisor repos — and their first
test file, `tests/notion_sync_test.sh` (14 checks). **The serious one:**
every `pull_request` event built a synthetic issue from the PR itself
(title, timestamp, labels) and sent it unconditionally, even when a real,
correct Notion row already existed for the linked issue — a PR whose title
or labels differ from its issue (the normal case) silently overwrote the
issue's own fields on every open, merge, or close. Fixed by splitting the
write path: an existing row gets only the fields a PR event actually owns
(`build_pr_mirror_props`); a not-yet-synced issue gets seeded from the real
GitHub issue (`fetch_issue`, using the `GITHUB_TOKEN` the workflow already
passed in but the script never read) instead of a fabrication. Also: a PR
closed without merging no longer gets stuck "In Review" forever (three
states, not two — merged / closed-unmerged / still open); `claude-code-review.yml`
now triggers on `ready_for_review`, not just `opened`/`synchronize`, so a
draft PR that goes ready with no further commit actually gets reviewed;
`notion-sync.yml`'s concurrency key is repo-wide instead of per-issue-number,
so a PR and the issue it closes can no longer race on the same row; and
`urlopen()` in `notion_sync.py` carries an explicit timeout so a stalled
Notion (or GitHub) connection fails the job promptly instead of occupying it
for hours. All five red-then-green: the harness was written and run against
the unmodified files first, so every failure below is a captured pre-fix
transcript, not a reconstruction — see `docs/BACKLOG.md` A22 for the exact
values. `scripts/verify.sh`: 147 → 162 assertions, all ten gates clean.

## 1.23.4 — A20: agents are selected, not assumed, and their absence is audited
Three gaps in the same shape, found in one 2026-08-12 audit. **The plan the user approves was lying by omission:** the interview's confirmation table listed the three conditional agents but not `verify-runner`, even though `LIFECYCLE.md`, `CADENCE.md`, and `ship-it/SKILL.md` all treat it as unconditional — the one agent that is *always* there was the one missing from what the user saw. `SKILL.md`'s `AGENTS:` line now reads `verify-runner (always-on)` separately from the conditional agents it derives. **Selection had no rule at all:** modules have an explicit interview-answer mapping; agents had nothing, and step 7 said "only the selected agents" without saying how anything got selected. Now: `schema-reviewer` / `integration-auditor` / `contract-drift-checker` are selected exactly when `database` / `data-integration` / `contracts` (respectively) is in `decided_modules` — not a new rule, just wiring up the pairing `ENFORCEMENT.md`'s honest-audit table already stated. Documented in `module-catalog.md`'s new *Agent Catalog* section and applied at `/project-init` step 3.7. **And nothing audited agent presence** — the A11 shape one layer up: a repo can lose `.claude/agents/*.md` files (deletion, a bad `.gitignore` entry, a sparse checkout) and nothing noticed. `scripts/check_agents.py` (new, registered as **G-07**) derives the expected agent set from which `.claude/rules/*.md` modules a repo actually holds, and flags any expected agent file that is missing or present-but-empty; not a CI gate, for the same reason `check_companions.py` isn't — a repo that never adopted the kit should not fail a check that assumes it did. `/project-audit`'s Enforcement layer runs it next to the A11 guard-local check it mirrors. `tests/agent_presence_test.sh` — 25 cases, later 30 after a review follow-up (adoption detection keyed on `.claude/.framework-state.json` instead of `.claude/rules/` presence, and a directory-masquerading-as-a-file case) — proves it red-then-green for all three conditional agents, the unconditional floor, the empty-file edge case, an unheld-module negative case, and G-03 fail-loud paths; wired into both loops of `scripts/verify.sh`.

## 1.23.3 — A18: every scaffolded repo's enforcement layer was dead — now it fires
`${CLAUDE_PLUGIN_ROOT}` does not resolve inside a project's own `.claude/settings.json` — a hook command built from it there is silently skipped, not run with an empty value (measured on CLI 2.1.220). `/project-init` wrote exactly that form, so **every repo this kit has ever scaffolded has had non-functional hooks**: no secrets guard, no rule-zero, no done-check, no session telemetry, since the day each was scaffolded. It looked protected — the `settings.json` entries were there — and was not.

Fix: `guard.sh`, `rule-zero.sh`, `done-check.sh`, `format.sh`, `verify-record.sh`, and `session-context.sh` are now declared once, globally, in the plugin's own `hooks/hooks.json` — the only place the variable resolves. Global means each one now matches on every repo the user has Claude Code open in, not only ones this kit scaffolded, so each hook's first move (`hook_opted_in`, `hooks/_parse.sh`) is a `.claude/.framework-state.json` presence check and an immediate `exit 0` otherwise — one `git rev-parse`, one `[ -f ]`, no stdin read, no dependency on jq/python3. Presence, not content, is the whole signal: a corrupted-but-present state file still counts as opted in (tested), so corrupting the marker can never silently disable enforcement the way removing the plugin already can. `/project-init` now writes only `guard-local.sh` into a target's `settings.json`; the exact broken form it used to emit is documented and replaced in `scaffold-spec.md`. **No migration needed for repos scaffolded before this fix** — every one already has `.claude/.framework-state.json` (written at step 7 or 11), so the moment a repo's plugin install updates past this version, its hooks start firing for real, with zero changes required in the target repo.

`hooks/hooks.json` and the opt-in gate are proven three ways: 16 new `tests/hooks_test.sh` cases (56 total) with a real red-then-green pair (the gate physically removed, then restored) showing the whole A18 section fail then pass; 13 new `tests/conformance_test.sh` cases (42 total) asserting the manifest parses, every command resolves to a real executable script, it stays in sync with this repo's own `settings.json`, and every declared hook actually calls the gate; and a live acceptance run against a real installed plugin and a real scaffolded-shape repo, `.enforcement-log` line included — `docs/acceptance/2026-08-12-a18-plugin-declared-hooks.md`. f4d-kit's own repo now carries `.claude/.framework-state.json` too, so its hooks stay armed under the new mechanism — deliberately double-wired alongside its existing repo-relative `settings.json` entries (A6: any exit-2 blocks regardless of order), at the cost of that one repo logging a real deny twice instead of once.

## 1.23.2 — A19: the scaffolder now names a real source for every workflow it writes
`/project-init` step 10 folded `verify.yml` into the `templates/github/` list built for `claude.yml`/`claude-code-review.yml`/`notion-sync.yml` — but `templates/github/` has no `verify.yml`; the repo has `templates/scaffold/verify.yml.tmpl` instead, which step 10 now cites and renders the same way `CLAUDE.md.tmpl` is (`{{DB_NAME}}`/`{{SETUP_CMDS}}`/`{{VERIFY}}` filled), unconditionally. The backlog's original write-up also claimed `gates.yml`/`preflight.yml` were unnamed by the scaffolder; that overstated it — step 11 already named both as destinations, they just had no source citation, unlike every sibling line in that step. Both now cite `${CLAUDE_PLUGIN_ROOT}/templates/github/<file>` explicitly, matching step 10's style, and step 10's own `claude.yml`/`claude-code-review.yml`/`notion-sync.yml` trio each now cite their own source individually instead of sharing one trailing clause — the shared-clause shape is exactly what let `verify.yml` get mis-scoped in the first place. `tests/conformance_test.sh` gained a 6-check section proving `SKILL.md` cites a real, existing, correct source for every `.github/workflows/` output, not just that the source file exists somewhere under `templates/` (which the pre-existing "spec-mandated artifacts" check already proved, and is exactly why it never caught this). Red-then-green: reverting only the `SKILL.md` fix reproduces 6/6 new checks failing (`pass=32 fail=6`); the fix turns all 6 green (`pass=38 fail=0`, full suite 153/153).

## 1.23.1 — A17: guess-list gate learns to see object-member lists
`check_guess_lists.py` matched only flat string-literal collections; GHL-MCP's real `CUSTOM_OBJECTS` — six files each redeclaring an array of *objects* sharing the same `objectKey` values — passed clean, the highest-value S-05 instance the re-audit found. New second detection path, name-agnostic like the first: a per-entry object property qualifies as an identifying key purely on shape (present on every entry, string-valued, distinct within its own array — nothing hardcodes "objectKey" or any other name literally), and its sorted values fingerprint exactly like a flat list, reusing the same 2+-files duplicate threshold (now a shared `MIN_MEMBERS` constant instead of the same magic number twice) and the same CLI-argument exclusion. Red-green measured against a fixture mirroring the real shape (`label`/`objectKey` and `label`/`objectId`/`objectKey` variants, values taken from the real repo): pre-fix reported "No duplicate constant lists found," post-fix blocks and names the `objectKey` fingerprint — and correctly does **not** unify the two files' `label` values, which drift in the real repo ("Building" vs "Buildings - Roof Records"), proving exact-match fingerprinting rather than fuzzy overlap. Fail-loud cases proven: an object-array with no discernible stable key (every column repeats) reports clean rather than crashing or false-flagging; a file that cannot be read (dangling symlink) is skipped without masking a real duplicate found elsewhere in the same walk, matching the pre-existing per-file read-exception path. Regression check: `verify.sh` run immediately before and after the code change (before any new test cases were added) produced byte-identical output at 159/159 assertions. Six new cases then added to `tests/gate_trio_test.sh` for the new path (43 → 49, full suite 159 → 165), all green; `check_guess_lists.py` still reports clean against this repo's own source post-change — no new false positives from the extension.

## 1.22.4 — A21: seven scanners agree on what a directory is
Six of the seven gate scripts each hand-rolled their own `SKIP` tuple instead of importing `_common.SKIP_DIRS` — the exact duplication `_common.py` was created to prevent, per its own docstring. They disagreed with each other: only `check_statelessness.py` and `check_guess_lists.py` skipped dot-prefixed directories; `check_test_count.py` skipped none by pattern (only `.git`/`.venv`/`.next` by exact name); `check_fixtures.py` matched skip names as a dirpath substring and never pruned its walk at all, so it silently walked every `node_modules` and `.git` tree in full. Measured: a fixture of 3 real test cases plus 80 phantom files in a `.cache/` directory took `check_test_count`'s count from 3 to 83; after this fix, 3 to 3. All seven scanners now consolidate on `_common.SKIP_DIRS` (a `frozenset`, extended additively per scanner where genuinely needed — e.g. `check_raw_sql.py` still excludes `migrations`/`db`/`sql`, documented inline rather than copied) and skip dot-directories uniformly. New `tests/scanner_agreement_test.sh` plants one trigger per scanner inside a single shared dot-directory and asserts all seven stay silent — wired into `verify.sh` (147 → 155 assertions). No user-facing or scaffolded-repo behavior changes; this is the kit's own tooling correctness.

## 1.22.2 — round-7 review fixes; S-04 honestly re-opened
Seven findings, all real. The one that matters most is a reversal: **S-04 goes back to tracked debt** — shipping an `assertNever` helper nobody is required to import enforces nothing, and marking it done was scoreboard inflation; its promote-when is now eslint `switch-exhaustiveness-check` / mypy strict-enum integration in the scaffold verify (44 enforced, 8 debts — the honest numbers). Recall fixes, re-measured on GHL-MCP: block-bodied promise catches (`.catch(() => { return []; })`) now caught (62→64) and log-hygiene scans complete multiline calls (1→5 — a formatter putting `req.body` on the next line no longer hides it). Correctness fixes: C-08 counts `async def test_` and compares from the **merge base** (tests added to main after branching are not the PR's deletions); G-05 enumerates baseline fixture paths so an outright-deleted fixture file is the strongest case removal, not an invisible one; the conformance MANDATED list includes the three newest gate scripts.


## 1.22.1 — A16: catch-empty gate tuned by measurement
The GHL-MCP re-audit measured the S-03 gate against reality: 147 raw findings, 93 of them the `request.json().catch(() => null)` body-parse idiom the original agent sweep excluded by judgment, and the flagship live sites (multi-statement catches — `reportSwallowed(...); return []`) missed by the return-first pattern. Both fixed: the body-parse idiom is excluded by design (a gate flagging 93 legitimate guards is a gate that gets disabled — A8), and the brace pattern now requires return-empty to *end* the block rather than start it. Re-measured post-fix: **62 findings, zero idiom noise, the F4 family caught mechanically**. Constructor-wrapped empties remain judgment and are documented as such. A17 filed: the guess-list gate is blind to object-member lists (the six-file `CUSTOM_OBJECTS` case).


## 1.22.0 — the last registry debt promoted; round-6 review fixes
**Every remaining global PROSE row is now enforced** (45 mechanically enforced, 7 project-conditional debts left): S-03 `check_catch_empty` (the catch-returns-empty trap the live audit found shipping raw IDs as report data), O-05 `check_log_hygiene` (payload/credential-shaped identifiers in log calls), C-08 `check_test_count` (repo-wide test-count decrease vs BASE_REF needs a stated `test-removal-ok` reason), G-05 fixture case-diff **implemented inside `check_fixtures`, whose docstring had claimed it for months** — the registry-honesty defect in the checker itself, now true — and S-04 `assertNever`/`assert_never` exhaustiveness helpers in both guard-test templates. All wired into `gates.yml`, all with red-then-green proofs and reasoned annotation escapes.

Round-6 fixes, all five findings real: the A6 artifact now rests on **direct observation** — marker-emitting hooks proved both hooks execute in both orders (no short-circuit; side-effectful hooks fire even on blocked calls — stated as a design consequence); both guards (plugin and fallback) treat key-present-but-nothing-extracted as a parse failure that blocks (`{"tool_input":{}}` and truncated payloads no longer slip through) and both now catch terminal `git push -f`; the conformance suite fail-louds once on missing PyYAML instead of ten confusing times, and its missing-piece check gained a curated list of every spec-mandated artifact (33 checked) instead of trusting a path regex that found four.


## 1.21.0 — O4 tier 1: mechanical conformance
`tests/conformance_test.sh` — 29 checks proving the pieces a scaffold is assembled from actually compose: every GitHub workflow template parses, the compose/verify templates **render** to valid YAML with tokens filled (the suite's first run caught exactly the right thing — raw `{{TOKEN}}` files aren't YAML, rendered ones must be), every hook and the fallback guard are executable, every registry section resolves as a module manifest against the always-on core, and every `templates/` path the init spec references exists (the missing-piece class the GHL-MCP audit hit). Tier 2 — behavioral, agent-run — is specified in `docs/acceptance/O4-protocol.md` and owns the debts bounded out of the A4/A5 acceptance: full-spec plan/execute parity, verify-green on the empty scaffold per module combo, and failing-verify-keeps-state. Cadence: one rich combo per minor release, all five before v2.0.


## 1.20.0 — A11: the guard floor that survives plugin absence
Every hook path is `${CLAUDE_PLUGIN_ROOT}/...` — uninstall the plugin and every guard silently vanishes while the repo looks fine (absence reads as permission; the jq bug one level up). Now `/project-init` writes `.claude/hooks/guard-local.sh` into the repo itself: self-contained (own minimal parser, no shared libs, deliberately no telemetry — zero dependencies that could fail with the plugin), blocking secret material (C-01), force-push (C-02), and unparseable input (G-03, fail-loud). Double-wired alongside the plugin guard — safe because A6 proved any exit-2 blocks in any order. `/project-audit` now asserts the fallback is present/executable/wired and that the installed plugin version matches the recorded framework state. Four red-green harness cases.


## 1.19.0 — A6: hook precedence, proven then documented
Three-run empirical protocol on CLI 2.1.220 — a validity control (allower only → write succeeds), then a blocker paired with an allower in both orders: **blocked both times**. Contract now in ENFORCEMENT.md: all matching hooks run; any exit-2 blocks; a passing hook cannot override; order affects only which message shows first. Plugin and project hook arrays merge per the settings docs — a project hook never disables a plugin hook. Design consequence stated: hooks must be independent, never order-reliant. Runnable protocol committed as the acceptance artifact.


## 1.18.1 — telemetry is fail-closed for secret-class denies
Round-4 review, both findings real. A C-01 deny can carry the secret anywhere in the command — a redirect payload (`printf sk-live-… > .env`), a quoted value, a key inside an RPC URL — shapes no assignment regex can enumerate. Secret-class rules (C-01, KS-01, KS-02) now **withhold the detail entirely**; the rule id and timestamp are the telemetry. Other rules keep assignment-redaction as defense in depth. Tested both ways (raw secrets proven absent from disk). And the harness now snapshots the kit's own enforcement log before running and asserts it is byte-identical after — a developer's legitimate local denies no longer fail the suite.


## 1.18.0 — round-3 review fixes + the UNREGISTERED denies get their rows
Twelve review findings on #8–#14, all verified, plus the registry decision: **C-09** (no destructive filesystem commands) and a new **Keysafety section** with **KS-01** (no broadcasting) / **KS-02** (no mainnet RPC) — the guard's three formerly-UNREGISTERED denies now carry real IDs (registry: 75 rules, 40 enforced). `UNREGISTERED` remains only as the fire-report's drift detector, now with zero standing members.

The serious ones: **the enforcement log no longer leaks what the guard blocks** — `log_deny` redacts `KEY/TOKEN/SECRET/PASSWORD`-style assignments before persisting (tested: the credential never reaches disk); **the hooks harness no longer pollutes the kit's real fire counts** (all deny cases run inside the disposable fixture, asserted); **`check_raw_sql` scans whole content** so multiline template literals can't walk past a per-line scan (tested red); **`check_pure_imports` covers Python filesystem IO** (`pathlib`/`os`/`shutil`/`tempfile`/`io`/`glob` imports and bare `open()` calls, `reopen(` proven not to false-positive); **`preexisting` gains a `null` sentinel** so "not yet captured" and "captured, empty" can never conflate in the saved-plan flow; **`upgrade.py` reconciliation now uses the renderer's complete validation** (single source — a manifest the audit rejects can no longer pass an upgrade) and reports NEW rules **against the recorded baseline** instead of naming every deliberately-unheld rule forever (`--apply` records registry IDs into the framework state).

Honesty tightenings from the same round: the import-time-registry annotation must now also cite **eager, unconditional startup imports** (a lazily-imported registration module recreates the drift); `session_report`'s promotion advice is evidence-gated on older CLIs (the hook injects an index, not contents); the audit describes a missing SessionStart as losing session-START records specifically (fire counts accrue independently); the A4/A5 acceptance claims are bounded to their exercised subset with full-spec parity and delete-discipline folded into O4; and the backlog's duplicated A6 entry is gone.


## 1.17.2 — A15 decided: session-context re-scoped, kept
The empirical test the twice-corrected doctrine demanded: a sentinel rule in a scratch repo's `.claude/rules/`, no hook, no `settings.json` — headless Claude Code **2.1.220** replied with the sentinel phrase exactly. Rules auto-load on the deployed CLI; the hook's loading rationale is dead. Decision: **re-scope, keep** — the hook's primary job is session telemetry (`.claude/.session-log`, the evidence layer for `session_report.py`, `/retro`, `/promote-rule`; retiring the hook would retire the evidence), and the rules-index injection stays as redundant defense-in-depth for older CLIs and `--setting-sources` exclusions, never to be cited as the reason rules load. All doctrine sites carry the evidence.


## 1.17.1 — A13: the import-time-registry exception, as doctrine
The live test's ST-01 false positive becomes a sanctioned, bounded exception: `statelessness.md` § *Import-time registries* documents why a module-level registry populated only at module top level is static-after-load (no cross-instance drift possible), the exact annotation (`stateless-ok import-time registration — <cite the call-site check>`), and the sharp boundary — any request-time registration makes it real ST-01, and since the scanner cannot see call-site timing across files, the annotation is a claim a reviewer verifies. The ST-01 finding message now points at the section. 4-case red-then-green harness added (`tests/statelessness_test.sh`).


## 1.17.0 — A10: enforcement telemetry
Hooks knew exactly what they blocked; nothing recorded it. Now every deny appends `timestamp<TAB>rule_id<TAB>detail` to `.claude/.enforcement-log` (shared `log_deny` in `_parse.sh`), each deny carries its registry ID in both the log and the block message, and `session_report.py` prints rules-by-fire-count on every path with an explicit flag for `UNREGISTERED` fires — three guard denies (broadcast, mainnet RPC, `rm -rf`) enforce rules the registry holds no row for, which is now visible instead of implicit. `/retro` reads the counts: fires-daily is a design problem the guard papers over; never-fires is a prune candidate. The hard property is tested (28-case harness): **telemetry can never weaken a deny** — with `.claude` unwritable the block still exits 2, and allowed commands write nothing.


## 1.16.1 — A4/A5 acceptance proven
The kill/re-run protocol ran against v1.16.0 in a scratch repo: killed after Round 2 → resumed at Round 3 with nothing re-asked; killed mid-scaffold after 6 files → resumed skipping exactly those (byte-identical, SHA-verified), completed 19 files with no duplication; commit-step re-entry skipped via `phases`; state deleted only after the Step-4 subset passed; `--plan` wrote zero files and its predeclared file-list matched `git ls-files` exactly (P-04). Also the A2 manifest's first scaffold exercise (22 rules validated). Verbatim evidence: `docs/acceptance/2026-08-11-a4-a5-acceptance.md`, honest bounds included (single-agent run; fresh-session gold proof still recommended; rich-scaffold verify is O4).


## 1.16.0 — the C-06 · D-06 · S-07 gate trio
Three PROSE rows promoted to enforced gates, per their own promote-when triggers:

- **C-06** `check_commits.py` — conventional-commit format on the PR range (`BASE_REF..HEAD`), 100-char subject ceiling, `Merge`/`Revert "` auto-subjects skipped. An empty or unresolvable range **blocks** (G-03): a gate that cannot see the commits it judges must not pass.
- **D-06** `check_raw_sql.py` — SQL string literals in handler-layer directories (`routes/ handlers/ controllers/ api/ endpoints/`) block; migrations and the data layer are excluded. Escape: `raw-sql-ok: <reason>` — an annotation **without** a reason is itself a violation.
- **S-07** `check_pure_imports.py` — network/DB/fs imports and bare `fetch()` calls in any `pure/` directory block (the global fetch needs no import to be IO). Escape: `pure-io-ok: <reason>`, same no-bare-annotations rule.

Both path-scoped gates state not-applicable out loud when the repo has no matching directories (A8: silence reads as "checked"). All three wired into the consolidated `gates.yml` job with their rule IDs. Proofs: `tests/gate_trio_test.sh`, 19 cases — every gate seen red on a planted violation, every fail-loud path seen to block, both annotations proven to require reasons. Registry: 37 mechanically enforced, 12 tracked debt.

## 1.15.0 — A2: the registry as a rendered view (A9 closed with it)
The framework's registry was S-05 committed by the framework that defines S-05: `/project-init` copied `REGISTRY.md` into every project and pruned it, so the framework registry and N project copies could disagree with no detection.

Now a project holds only `.claude/rules/manifest.json` (`{"rules": [...], "overrides": {...}}`). Rule text and status live in one place — the plugin registry — and `scripts/render_registry.py` renders a project's view on demand; `--validate` fails on any broken reference. Fail-loud throughout (G-03): unknown ID, override on an unheld rule, empty rules list, unknown manifest key, missing or unparseable inputs, and duplicate IDs on either side all block — an empty rendering that "worked" would be S-01 committed by the tool built to prevent it. `upgrade.py` reconciles manifests: new plugin rules surface as adoption candidates, a committed project `REGISTRY.md` flags as `STALE-REGISTRY`, and broken references exit 1. `REGISTRY.md` itself now states ID permanence (A9): supersede with a new ID, never renumber.

Proofs: `tests/render_registry_test.sh`, 11 cases, every fail-loud path seen red first; plus a live `upgrade.py` red/green exit-code check. `/project-init` writes manifests instead of copies; `/project-audit` validates them and treats a committed registry copy as a finding.

## 1.14.2 — round-2 review fixes, and the load-path doctrine corrected a second time
Nine review findings on #5/#6/#7, all verified. The big one: **1.14.1's correction was itself incomplete** — per the Claude Code memory docs, unscoped `.claude/rules/*.md` **auto-load at launch** (recursively, same priority as `.claude/CLAUDE.md`), so the claim that "only CLAUDE.md auto-loads" was false too. All doctrine sites now state the docs-verified truth; `session-context.sh` is re-labelled defense-in-depth pending **A15** (retire or re-justify, with an empirical `/context` test — its session-log telemetry job must survive either way). `session_report.py`'s decide-now branch no longer treats subdirectory starts as a broken load path (every logged session ran the hook that wrote the log).

Also fixed: legacy v1.13.0 state files without `preexisting`/`phases` are rejected like corrupt state instead of silently defaulting (a defaulted-empty inventory authorizes overwriting pre-existing RETROFIT files); the `preexisting` snapshot moves from plan confirmation to **first entry into Step 3** (files created between a saved plan and execution now land in the inventory) and is never recaptured on resume; the dry-run plan must list **host-level toolchain mutations** (`corepack enable`, `foundryup`, `uv init`); absent-mode gains an explicit discover-and-evaluate step for the repo's real instruction files; the statelessness gate runs from the **plugin's** copy on unscaffolded repos; and a missing org profile is recommended, never executed, mid-audit.

## 1.14.1 — the load-path doctrine was wrong, and it taught a live audit a false finding
The kit asserted in seven places that a session started in a subdirectory "never loads the repo-root instruction files." Live evidence disproved it: `CLAUDE.md` auto-loads with an **upward walk** from the session's cwd — a root file reaches `dist/reporting` fine (verified directly, and the audited repo's own phase-0 plan had verified the same independently, labelled "diagnosed wrong once already"). The GHL-MCP audit repeated the kit's claim verbatim as finding M2 and had to retract it under PR review.

What was, and remains, true: `AGENTS.md`-style guides and the `.claude/rules/*.md` modules never auto-load — without `session-context.sh` every session runs on `CLAUDE.md` alone. All seven sites now state that; `session_report.py`'s subdirectory FINDING is downgraded to a relative-path NOTE (doubly wrong before: sessions in its log had, by construction, run the hook that wrote the log). The hook itself is unchanged and still ships.

Also from the same review round: **no in-progress markers may survive into a committed audit report** — the live audit shipped a "recorded once the run completes" placeholder alongside the completed result.

## 1.14.0 — what the first live test taught the audit
`/project-audit` ran for the first time against a real, unscaffolded repo (GHL-MCP, on a scratch clone → their PR #1042) and two structural gaps surfaced.

**FRAMEWORK-absent mode.** The skill assumed a scaffolded repo; on an inherited or unscaffolded one the auditor had to improvise which checks translate. Now specified: which checks run as-is (enforcement layer judged against the repo's own instruction files, verify integrity, rules-vs-reality, spot checks), which are skipped **by construction** and must be declared in *Not checked* (version/drift, kit-registry honesty, kit gate scripts), and org checks recommend `/org-profile` when no profile exists.

**Adoption recommendation** is now a required report section when FRAMEWORK is absent or partial: the specific slice to adopt first, what NOT to adopt because a mature local equivalent exists, and the next step (`--plan`). Advice with dangers attached — merging the report adopts nothing.

**Backlog:** A13 opened for the ST-01 import-time-registry false positive found live; the test record and its foldbacks are in the backlog.

## 1.13.1 — review fixes from the first live test's PRs
Six review findings on #2/#3/#4, all confirmed against the shipped text:

- **Resume could not tell "pre-existing" from "interrupted mid-write"** — in RETROFIT both are absent from `written_files`, and the rules said both "rewrite it" and "never touch it". The state file now captures a `preexisting` inventory at plan confirmation; unrecorded planned targets redo their retrofit-safe (idempotent) operation when pre-existing, rewrite outright when not.
- **The scaffold commit was not resumable** — interrupt after the commit, resume, and `git commit` fails on `nothing to commit`, blocking verification and cleanup. Non-file steps now record into a `phases` map; the commit must be recorded, idempotent side effects may re-run.
- **Plan mode wrote the state file it claimed not to write** — a `--plan` on a RETROFIT repo left an untracked file in the target, contradicting "writes nothing". Plan mode now keeps state in memory and *offers* persistence at the end; only an explicit yes writes.
- **The plan omitted non-file side effects** — the commit, the upgrade baseline, the **remote** `SINGLE_INSTANCE` variable, and Step 4's stack/migrations/seed never appeared in the "complete" plan. They are now required plan output; P-04 parity covers effects, not just files.
- **"Read-only" contradicted the mandated report write** — the audit header now states its single exemption explicitly.
- **`file:line` was required where no line can exist** — absence and external-state findings may now cite a listing, command output, or external-system state; never omit a finding for lack of a line, never invent one.

## 1.13.0 — audit writes its report as a document
`/project-audit` now writes `docs/f4d-audit-<date>.md` into the audited repo (dedicated branch, never pushed unasked) — header, three-sentence summary, findings with file:line evidence, proposed changes ranked by what bites soonest with an explicit **danger** column (what adopting each change could break in this repo — a hook blocking a current workflow, a gate going red on existing code), a prioritized todo list handable to a fresh session, and a **Not checked** section, because silence reads as "checked and fine". The document is the only file the audit writes; the terminal summary stays. Requested for the first live retrofit test: audit a scratch clone, review the document, decide separately.

## 1.12.0 — A5: scaffolder dry run
`/project-init --plan` runs the identical interview and decision path, prints the complete plan — file tree, modules with the answer that decided each, gates/hooks/agents, local-stack choice, verify command — and stops without writing. P-04 applied to the scaffolder itself: the registry demanded preview/execute parity of every project while the scaffolder had no preview at all. Plan mode persists interview state, so a later real run resumes from the confirmed plan without re-asking (composes with 1.11.0). RETROFIT repos get `--plan` first by default.

## 1.11.0 — A4: resumable interview
`/project-init` was the longest single operation in the system — four interview rounds and ~30 file writes — with no persistence: an interruption lost everything and left a half-written directory.

Now: answers persist to `.claude/.init-state.json` after every completed round, the confirmed plan is recorded at Step 2 approval, and every scaffold write appends to `written_files`. A new Step 0 detects existing state and offers resume-or-discard — with a fail-loud path for a corrupt state file (never guess at partial state). The scaffold is idempotent on resume: skip exactly what `written_files` records; on-disk-but-unrecorded means interrupted mid-write, so rewrite. In RETROFIT, the resume list governs only files the run wrote — the never-overwrite rules still own everything pre-existing. Success (Step 4 verification passing) is the only thing that deletes the state; interrupted and failed runs both keep it. The state file is gitignored via `gitignore.tmpl`; its shape lives in one place, `scaffold-spec.md` § *Init state file*.

**Acceptance test still owed:** the kill-after-Round-2 / kill-mid-scaffold live re-run proof needs an interactive `/project-init` in a scratch repo. Until that runs, this is implemented-to-spec, not proven — same standard as any other guard.

## 1.10.2
- B-03 closed: the kit is published as `f4d/f4d-dev-env-configurator` (private). START_HERE, README install section, and the backlog now reference the real remote instead of instructing a push to a repo name that never existed. The plugin/product name remains `f4d-kit`; only repo-slug references changed.

## 1.10.1
- Added `docs/BACKLOG.md` — every open finding, blocked item, registry debt entry, opportunity, and working agreement in resumable form. Each item carries why it matters, what to build, done-when criteria, and files touched, so work can be picked up cold without re-deriving the reasoning.

## 1.10.0 — architecture pass
Full architecture review in `docs/ARCHITECTURE_REVIEW.md`. Verdict: the enforcement architecture is sound; the lifecycle architecture was built for day one and under-built for day two hundred. Twelve findings, top three fixed here.

**Framework violated its own G-02.** Five of seven hooks had no test, including `session-context.sh` — the load-path fix, the most load-bearing hook in the system. Now 24 test cases covering all seven. Writing those tests found a real bug: `done-check.sh` used `git diff HEAD`, which returns nothing in a repo with no commits and **misses untracked files entirely** — a brand new source file did not count as a change. Now uses `git status --porcelain`.

**A1 — upgrade path (critical).** `scripts/upgrade.py` + `/framework-upgrade`. Diffs a project's `.claude/` against the plugin and classifies each file as UNCHANGED / FRAMEWORK / LOCAL / CONFLICT / NEW / ORPHAN against a recorded baseline. Applies FRAMEWORK only; local customizations survive; conflicts go to a human. All four classifications proved with a live test. Without this, N repos scaffolded over N months sit at N versions and *"we are always working on the same system"* quietly becomes false.

**A3 — the framework had no ADRs of its own.** Three recorded: plugin distribution, GitHub over Linear, and document-everything-track-enforcement. Each with the alternatives that lost and why.

**A12 — secret preflight.** `preflight.yml` asserts that `CLAUDE_CODE_OAUTH_TOKEN`, `NOTION_TOKEN`, and `NOTION_WORK_DB` exist when the workflows depending on them are present. The framework told you what to add and never checked that you did.

**A7 / A8 — gate cost and false firing.** The five script gates collapse into one job: one checkout, one Python setup, all five checks with grouped output. `STATELESS_SINGLE_INSTANCE` now comes from a repo variable the scaffolder sets from the interview answer, so the statelessness gate does not fire wrongly on a single-instance project.

Remaining findings A2, A4, A5, A6, A9, A10, A11 are documented with severity, effort, and priority in the review.

## 1.9.0 — statelessness
A failure class the framework had no coverage for: state that works on one instance and fails intermittently on two. Structurally invisible, because local dev, tests, and CI are all single-instance — the first multi-instance environment is production.

**Interview** — Round 1 gains *"Will this ever run more than one instance?"* (`yes` / `no` / `serverless`; autoscale and serverless are both yes). A `yes` includes the module, switches the local stack to two instances, and ships the cross-instance tests — not asked about separately, that is what yes means. A `no` gets ADR 002 recording the choice and its reversal cost. Round 3 adds two follow-ups: what survives between requests (walk the list, don't accept "nothing"), and where long-running progress lives if the instance dies.

**`templates/rules/statelessness.md`** — the contract (any instance serves any request; any instance may die between requests), a where-state-must-live table covering sessions, caches, rate limits, locks, uploads, temp files, jobs, schedules, progress, and websockets, and the rules that follow.

**`scripts/check_statelessness.py`** — gate for ST-01..ST-07: module-level mutable collections, in-process locks, in-process schedulers, local-disk writes, migrations at boot, in-memory sessions, in-process rate limiters. Line-level `stateless-ok` annotation for genuine exceptions. Proved red on five planted violations, green when clean, and fixed so it no longer matches its own pattern table.

**`templates/scaffold/docker-compose.multi.yml.tmpl`** — the environment fix, and the most important part of this release. Two app instances behind nginx round-robin, redis for shared state, and migrations as a **separate** service so instances never race at boot. Now the default local stack for any multi-instance project; single-instance requires a recorded decision.

**`templates/tests/statelessness_test.py`** — cross-instance write-then-read, session survives an instance switch, rate limit is shared across instances, idempotent write through the load balancer, and a restart-loses-nothing test.

**Registry** — 14 new ST-* rules. Seven are gated, one is scaffold-enforced, one is tested; the rest carry project-conditional promote-when triggers.

**Also** — Definition of Done gained a Statelessness section, `/project-audit` checks whether the local stack is single-instance (if it is, every ST-* bug in that repo is currently invisible), and the org profile gained `multi_instance` and `shared_store` defaults.

## 1.8.0 — document everything, enforce what's ready, track the rest
Answers "can't we just document them now and figure out enforcement later?" — yes, provided the gap is tracked rather than forgotten.

**`templates/rules/REGISTRY.md`** — every rule the framework holds, with an ID (C-, G-, S-, P-, D-, I-, K-, M-, T-, O-), the layer it should live in, what enforces it today, and a promote-when trigger for anything still prose. `PROSE` on a mechanisable rule is now a tracked debt with a ticket, not an invisible gap. `JUDGMENT` is a finished state — do not mechanize it.

**Holes closed**
- H2 *agents were advisory* → `templates/github/gates.yml`: six CI jobs that FAIL the build, each named with the rule IDs it enforces. The schema job makes the agent's verdict a gate by acting on its PASS/FAIL line.
- H3 *rollback never tested* → `scripts/check_rollback.py`: every migration needs a down-path or an explicit irreversible declaration, and "revert the commit" is rejected as a rollback when a migration ran.
- H4 *contract drift not version-enforced* → `scripts/check_contract_pin.py`: fails when a consumer is unpinned or more than one major behind.
- H5 *fixtures rot silently* → `scripts/check_fixtures.py`: requires `_meta.recorded_at`, fails at 90 days, and requires all four fixtures per adapter.
- H6 *hub+local had no reconciliation* → `/notion-sync` Mode 5: three-way divergence report, hub canonical for mirror fields, and a 5%-for-two-checks trigger to drop the mode.
- H7 *promotion path was manual* → `/promote-rule`: identify by ID, confirm the rule was actually in context, choose the layer, build it red-first, wire it, update the registry, and promote to the framework only after it has proved itself in one repo. Also owns demotion.
- S-05 *guess lists* → `scripts/check_guess_lists.py`. It immediately caught real duplication in this kit's own scripts; fixed by extracting `scripts/_common.py`.

**Reference tests** — `templates/tests/guard_tests.{py,ts}` implement S-01 (non-empty before assertion) and S-02 (no raw ids in output) in both languages, each with a case proving the guard fails. Copied into every project by `/project-init`.

**Audit** — `/project-audit` now verifies **registry honesty**: every row claiming HOOK/TEST/GATE must have that check actually wired and running. A registry asserting enforcement that does not exist is worse than no registry.

## 1.7.0 — evidence, not recollection
- **Session telemetry.** `session-context.sh` now appends to `.claude/.session-log`: timestamp, whether the session started at the repo root, which subdirectory, whether CLAUDE.md existed, and the rules count. `verify-record.sh` (PostToolUse:Bash) records verify runs.
- **`scripts/session_report.py`** turns that log into findings with counts — how many sessions loaded no rules, how often verify ran, whether the rules set changed mid-window. This replaces "observe for a week and then decide," which no agent can do because every session starts blank.
- `/project-audit` and `/retro` now run the report **before** forming any opinion, and say so explicitly when there is no log rather than waiting for one.
- **`templates/process/TEST_STRATEGY.md`** — the pyramid mapped to this framework's real failure classes, per-component coverage, the seven guard tests ranked by yield, non-percentage coverage targets, and the four anti-patterns already hit in this kit.
- `.session-log` and `.last-verify` gitignored — local telemetry, not shared state.

## 1.6.0 — enforcement pass
Driven by a field report: a full set of rules was in force and none of them fired, because they were prose.

**Fixed a defect in this kit's own guards.** `guard.sh` depended on `jq`. On any machine without it the parse returned empty and the hook **exited 0 silently** — a key-safety guard that looked installed and enforced nothing. Both hooks now fall back to python3, then sed, and **fail loud (exit 2) rather than allowing** when input cannot be parsed.

**New hooks**
- `session-context.sh` (SessionStart) — fixes the load-path defect. `CLAUDE.md` only auto-loads from the directory a session starts in; a session started in `dist/` or `packages/x/` never saw the repo-root rules at all. This walks to the repo root and injects them regardless of cwd.
- `rule-zero.sh` (PreToolUse:Write) — blocks creating a variant alongside an existing canonical file (`reportV2`, `report-final`, `new-report`) until the existing one is named. Mechanical fix for the twenty-near-duplicates pattern.
- `done-check.sh` (Stop) — refuses a silent "done" when source changed and verify never ran, or ran before the newest change.

**New rules modules** — `guards` and `silent-degradation` are now always included, never asked about
- `silent-degradation` — no degrade-to-default, the `catch → []` trap that passes every downstream "is anything missing" gate, empty-collection vacuous pass, guess lists, one canonical resolver, the hardcode boundary, never render a raw id, cross-check load-bearing numbers
- `guards` — red-then-green hygiene, where a rule belongs by layer, naming the unguardable residual
- `capability-parity` — consumer enumeration on contract change, UI-as-proof, row-level vs call-level failure, preview/execute parity

**New process doc** — `templates/process/ENFORCEMENT.md`: the three-layer model, the load-path defect, and an honest audit of which f4d-kit rules are still prose that should not be, in priority order

**Other**
- Definition of Done gained Guard hygiene and Contract changes sections
- `/retro` now asks "was it even in context?" before "was it ignored?"
- `/project-audit` checks the enforcement layer first, and greps for the silent-degradation patterns
- `verify.yml` gained path filters so docs-only changes skip the full gate
- Added `tests/hooks_test.sh` — 14 red-then-green cases, all passing

## 1.5.0
- **Hub segmentation.** Work DB gained `Company` and `Hub Mode` properties plus By-company and per-company views. One hub database serves every company; adding a company is an option plus a view, not a new database
- Added the hub-mode branch to both interviews: `hub` (default) | `hub+local` | `local`, with the cost of each stated. Recorded in the org profile so it is asked once per company
- Added `templates/notion/SYNC_ARCHITECTURE.md` — documents the GitHub Actions path (shipped), the Notion Workers path (beta target, declarative schema and hosted runtime), and External Agents (alpha), with explicit migration triggers and the four invariants that make migration a swap rather than a rewrite
- `/notion-sync` now points at the architecture doc before any sync change

## 1.4.0
- Added `/repo-builder` — the front door. Orchestrates `/org-profile` → `/project-init` → `/notion-sync` → `gh repo create` → first commit → push → verify, in one pass
- Narrowed `claude-code-review.yml` to high-risk paths only: migrations, models, api/routes/handlers, webhooks, adapters, auth, billing, crypto/hashing, `*.sol`, openapi, schemas, workflows, Dockerfiles. Everything else is covered by verify plus human review
- Review prompt is now a ranked checklist rather than an open request, and explicitly excludes style

## 1.3.0
- Added `/notion-sync` — Notion Work DB as the triage UX and work queue over GitHub Issues
- `templates/notion/WORK_DB_SCHEMA.md` — schema with explicit field ownership (GitHub mirror vs triage vs context) and seven views including a Stale view for sync health
- `scripts/notion_sync.py` — one-directional GitHub → Notion sync; writes only the fields it owns, preserves all triage fields
- `templates/github/` — `notion-sync.yml`, `claude.yml` (issue → PR), `claude-code-review.yml` (auto review), plus `bug.yml` and `feature.yml` issue forms
- `/work-intake` now triages in the Work DB; `/ship-it` writes spec, ADR, and notes back
- `/project-init` wires the workflows and issue templates when the org profile has the GitHub App and a Work DB
- Org profile gained `notion_work_db`

## 1.2.0
- Added `/org-profile` — company-level context captured once per company, inherited by every project in it
- Added `templates/org/ORG.template.yml` — profile schema: identity, GitHub org, conventions, stack defaults, automation, business context, constraints
- `/project-init` gained **Round 0**: which company, project identity, silo-vs-shared, audience, expected lifespan. Runs `/org-profile` automatically when no profile exists, and skips every question a profile already answers
- Scaffold now writes `.claude/rules/org.md` from the company's constraints block
- CLAUDE.md template carries an org/audience/lifespan header
- `/project-audit` checks org alignment: profile exists, constraints in sync, conventions match, board membership

## 1.1.0
- Added the product management layer: `/work-intake`, `/write-spec`, `/decision-record`, `/ship-it`, `/retro`
- Added `templates/process/`: LIFECYCLE, DEFINITION (Ready + Done), CADENCE, and spec/ADR/PR templates
- `/project-init` now scaffolds `docs/specs/`, `docs/decisions/`, `docs/log.md`, `docs/intake.md`, the PR template, and ADR 001 for the chosen stack
- CLAUDE.md template gained a Process section pointing at the lifecycle
- Generalized webhook signature header convention — no project-specific naming

## 1.0.0
- Initial framework: `/project-init` interview skill, 17 rules modules, guard/format hooks, 4 subagents, scaffold templates, `/project-audit`, `/new-module`, `/new-integration`, `/contract-first`
