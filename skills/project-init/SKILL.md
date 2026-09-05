---
name: project-init
description: Interview the user about a new or existing software project, then scaffold or retrofit its full Claude development environment — CLAUDE.md, rules modules, hooks, subagents, verify commands, local stack, and contract layer. Use this whenever the user starts a new repo, says "new project", "set up a project", "scaffold this", "rightsize this repo", "get this project ready for Claude", "add rules/hooks to this repo", or when they are about to begin building an API-based, DB-backed web app. Also use when an existing repo has no CLAUDE.md, no .claude/ directory, or inconsistent conventions compared to their other projects.
---

# Project Init

Scaffold a Claude development environment sized to what the project actually is. Two modes:

- **NEW** — empty or near-empty directory. Full scaffold.
- **RETROFIT** — existing code. Detect what's there, add what's missing, change nothing that works.

Detect mode by checking for `package.json`, `pyproject.toml`, `.git`, and existing source directories. State which mode you're in and confirm before proceeding.

---

## Step 0 — Resume check (always first)

Check for `.claude/.init-state.json` before anything else — including mode detection.

- **Absent** → fresh run. Proceed to Step 1.
- **Present and parseable** → a previous init was interrupted. Show a compact summary — mode, rounds completed, answers given, files already written — and ask: **resume from the next step, or discard and start fresh?** Never silently re-ask what the file already answers, and never silently discard it.
- **Present but unparseable — or parseable with a legacy/foreign schema** (missing fields the spec requires, e.g. `preexisting`, `phases`) → say so loudly, show the raw contents, and ask discard-or-stop. Do not guess at partial state and do not default missing fields; a corrupt or legacy state file treated as valid re-runs the wrong half of the scaffold, and a defaulted-empty `preexisting` authorizes overwriting pre-existing files in RETROFIT.

Format and resume rules: `references/scaffold-spec.md` § *Init state file*.

---

## Step 1 — Interview

Ask in **four rounds**. Do not dump all questions at once. After each round, state what you've concluded so the user can correct you cheaply — then persist the round's answers to `.claude/.init-state.json`. An interrupted interview resumes at the next round; it never restarts.

Use `ask_user_input_v0` if available; otherwise ask as prose, one round per message.

### Round 0 — Company & project identity (always first)

```bash
ls ~/.claude/f4d/orgs/
```

1. **Which company is this project for?**

**If a profile exists** for that company: read it, state the defaults it supplies in one line, and move to Round 1. Do not re-ask anything it answers.

**If no profile exists:** run `/org-profile` now, then return here. Company-level facts are captured once per company — GitHub org, conventions, stack defaults, automation settings, and constraints — and every project in that company inherits them.

Then ask the project-identity questions the profile cannot answer:

2. **Project name and repo slug?**
3. **Is this project shared with the rest of this company's work, or siloed from it?** — decides whether it joins the org Project board and shares cadence. Default to the company's `coherence` setting; ask only to confirm.
4. **Who is this for — internal, a named client, or a product with outside users?**
5. **Expected lifespan?** — `throwaway / experiment` | `ongoing product` | `client deliverable with a handoff`
6. **Where is this project's work tracked?** — the hub-mode branch:

   | Answer | Meaning | Cost |
   |---|---|---|
   | **`hub`** *(default)* | The central Work DB in the hub workspace only. `Company` and `Project` segment it. | None |
   | **`hub+local`** | Hub row is canonical, mirrored into that company's own workspace | A second sync target to maintain |
   | **`local`** | That company's own workspace only, no hub row | Loses cross-company roll-up |

   Default to `hub` unless the company profile says otherwise. Propose it rather than asking open-ended: *"Tracking in the hub, same as everything else — or does this one need its own workspace?"*

   Choose `hub+local` only when someone **outside your workspace** needs to see status. Choose `local` only for contractual isolation. Both are real maintenance; `hub` is free.

   Whatever is chosen becomes `Hub Mode` on every row this project creates, and is recorded in the org profile so the question isn't re-asked per project in that company.

Question 5 matters more than it looks. A throwaway gets core rules and nothing else. A client deliverable with a handoff needs documentation, a README written for a stranger, and no dependencies the client can't maintain.

Carry into every later step: the company's `constraints` block goes into `.claude/rules/org.md` verbatim, and its conventions (webhook prefix, package scope, env prefix) apply without asking.

### Round 1 — Shape (always ask)

1. **What does this project do, in one or two sentences?**
2. **Primary language for the backend?** — `python` / `typescript` / `both` / `other`
3. **Is there a user-facing frontend?** — `none, API only` / `SSR web app` / `SPA` / `admin UI only`
4. **Database?** — `postgres` / `sqlite` / `mongo` / `none yet` / `other`
5. **Will this ever run more than one instance?** — `yes` / `no` / `serverless`

   Ask it plainly; it decides more than any other question in Round 1. Autoscale,
   multiple containers, and serverless are all **yes** — serverless most of all,
   since every request may hit a cold instance.

   If `yes` or `serverless`, the `statelessness` module is included, the local
   stack is the **two-instance** compose file, and the cross-instance tests ship
   with the scaffold. Do not ask whether they want this; it is what `yes` means.

   If `no`: ask *"what would have to change for that to become yes?"* and record
   the answer. Single-instance is a legitimate choice, but it should be a decision
   with a stated reversal cost, not an assumption. Write ADR 002 for it.

### Round 2 — Integration surface (always ask)

5. **What external systems does this talk to?** List them. For each, note whether it is: read-only, write, or both; and whether it is metered/paid.
6. **Does anything call *in* — webhooks, callbacks, third-party pushes?**
7. **Is this standalone, or part of a group of repos that must agree on a contract?**
8. **Is any part of this already live / in production?**

Design tooling (Figma/Notion/Drive) is the same kind of integration-surface
question, but it can't be asked here — its trigger is which design bundle got
picked, and that isn't decided until Round 3. It's asked there instead, as the
row immediately after the design-bundle row.

### Round 3 — Conditional modules

Only ask what applies, based on Rounds 1–2. Most rows pull in a rules module and its associated tests, hooks, and local-stack pieces.

| Ask when | Question | Enables module |
|---|---|---|
| Any file input/output mentioned | **Does this project store or serve user files? If so, where — S3/R2, local disk, DB blobs?** | `storage` |
| Storage = yes | **Do files need content-addressing, dedupe, or reproducible hashes?** | `determinism` |
| Multi-instance = yes | **What has to survive between requests — sessions, caches, rate limits, uploads in progress, background jobs, schedules, locks?** Go through the list; do not accept "nothing" without walking it. | shared-store services in the local stack |
| Multi-instance = yes | **Anything long-running — jobs, imports, pipelines?** If so, where does progress live, and what happens if the instance running it dies? | queue + durable progress |
| Money, pricing, invoices, splits, payouts mentioned | **Does this project compute or move money?** | `money` |
| Chain, wallet, mint, token, contract mentioned | **Any blockchain or smart-contract component? Which chains?** | `blockchain` + `keysafety` |
| Multiple sources in Q5 | **Do you need to reconcile or merge data across those sources into one canonical record?** | `data-integration` |
| Frontend != none | **Does this project have a UI surface? If so, which design capabilities does it need — tokens, verification, content, direction, build, governance?** | `design-tokens` · `design-a11y` · `design-components` · `design-handoff` |
| Design bundle selected | **Do you need Figma, Notion, or Drive reachable from this project?** | `.mcp.json` entries |
| Q8 = yes | **What in production must never break, and what must never be touched by an agent session?** | `livesystem` |
| Always | **Which companion plugins should this repo expect?** Default: `superpowers` (MIT, multi-harness — ships `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`; process skills for TDD, planning, debugging, code review). Offered, never imposed — a declaration is a promise the audit will check. | — (declaration in `.framework-state.json`, not a rules module) |
| PII, health, payment data hinted | **Does this hold personal, payment, or regulated data?** | `dataprotection` |

**Bundle dependencies.** `design.direction` and `design.build` require
`design.tokens`; `design.govern` requires `design.verify`. Pull the dependency in
automatically and say so, the same way `blockchain` pulls in `keysafety`. Never
scaffold a dependent bundle without its base — the gates it relies on would have
nothing to read. Which `design-*` module(s) each capability actually adds:
`references/module-catalog.md` § *Design modules*.

**Rule:** never assume a module. If storage wasn't mentioned, ask — don't skip and don't include. Storage is configured per project, never inherited by default.

**Exception — always included, never asked about:** `core`, `guards`, `silent-degradation`. These address the failure class that survives review, and a project that opts out of them has opted out of the point of the framework.

**Agents follow the same logic, one level up — never asked about directly.**
`verify-runner` is unconditional (every PR runs it, regardless of stack).
`schema-reviewer` / `integration-auditor` / `contract-drift-checker` are each
selected exactly when `database` / `data-integration` / `contracts`
(respectively) is among the modules just decided — the same pairing
`${CLAUDE_PLUGIN_ROOT}/templates/process/ENFORCEMENT.md`'s honest-audit table already states, not a
new rule. `design-critic` is selected exactly when any of the four `design-*`
modules is among the modules just decided — the same one-level-up pairing, not
a separate interview question. Full table: `references/module-catalog.md` §
*Agent Catalog*.

---

## Step 2 — Confirm the plan

Before writing anything, print a table and wait for approval:

```
ORG:       F4 Digital (f4d)  — profile found, defaults applied
PROJECT:   invoice-sync  |  shared with org board  |  client deliverable
MODE:      NEW
STACK:     Python 3.12 (FastAPI) + TypeScript (Next.js) + Postgres
MODULES:   core, api, database, python, typescript, data-integration, storage
SKIPPED:   determinism, money, blockchain, keysafety, frontend-perf, livesystem
HOOKS:     guard.sh (secrets, prod), format.sh
AGENTS:    verify-runner (always-on)  |  schema-reviewer, integration-auditor (selected: database, data-integration)
COMPANIONS: superpowers >= 6.2.0   (declared; /project-audit will verify it stays installed)
VERIFY:    uv run ruff check . && uv run mypy . && uv run pytest && pnpm typecheck && pnpm test
LOCAL:     docker compose — postgres 16, mailpit, minio (R2-compatible)
```

Ask: *"Anything to add or drop before I write it?"*

On approval, record the confirmed plan — mode and `decided_modules` — in `.claude/.init-state.json`. A resume after this point skips straight to the scaffold.

---

## Plan mode — dry run

When invoked as `/project-init --plan`, or the user asks for a preview, a dry
run, or "show me what this would do": run Steps 0–2 exactly as normal — same
interview, same decisions, same confirmation table — then, instead of Step 3,
print the complete plan and **stop without writing anything**:

- the full file tree Step 3 would write, path by path
- the modules included and skipped, with the interview answer that decided each
- the gates, hooks, and agents that would be wired
- the local-stack choice (single vs two-instance) and the verify command
- **every non-file side effect execution would perform**: the scaffold commit,
  `upgrade.py --apply` recording the framework baseline, the `SINGLE_INSTANCE`
  repo variable (a **remote** change), Step 4's stack start with its migrations
  and seed, and any **host-level toolchain mutations** the chosen stack requires
  (`corepack enable`, `uv init`, `curl | bash && foundryup` — user-level changes
  outside the target repo, plus the package caches they populate). A plan that
  lists only files while execution also commits, records, and mutates remote and
  host state is not at parity.

This is registry rule **P-04 applied to the scaffolder itself**: the plan is
produced by the same decision path as a real run, output only — never a separate
description that can drift from what execute would do. Anything the plan cannot
state exactly, it must say so rather than approximate.

**Plan mode writes nothing — including the state file.** The Step 1/Step 2
persistence instructions do not apply in plan mode; interview state stays in
memory. After printing the plan, offer once: *"Save these answers to
`.claude/.init-state.json` so a real run resumes from this plan?"* — only that
explicit yes writes the file. A dry run that silently leaves an untracked state
file in the target repo has already violated its own contract. On a RETROFIT
repo, run `--plan` first by default and show the plan before proposing to
execute.

---

## Step 3 — Write the scaffold

Read `references/scaffold-spec.md` for exact file contents and layout. At entry into this step, if `preexisting` is `null` — and only then — capture which planned targets already exist on disk (`null` = never captured; `[]` = captured and empty; a resume never recaptures). After each file lands, append its path to `written_files`; after each non-file step completes (the commit, the upgrade baseline, the repo variable), record it in `phases`. Resume semantics — including how pre-existing targets are re-done safely and why the commit must be phase-tracked — live in the spec's *Init state file* section. Write in this order:

1. `.gitignore`, toolchain pins (`.python-version`, `packageManager`)
1a. `CLAUDE.local.md` — personal preferences, gitignored. Write the file with a
   one-line header comment and add it to `.gitignore`. Every project gets one,
   design or not.
2. `CLAUDE.md` — assembled from `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/CLAUDE.md.tmpl`, **kept under 80 lines**
3. `.claude/rules/org.md` — the company's `constraints` block, copied verbatim from its org profile
4. `.claude/rules/*.md` — copy only the selected modules from `${CLAUDE_PLUGIN_ROOT}/templates/rules/`. **Never copy `REGISTRY.md`** — instead write `.claude/rules/manifest.json`: `{"rules": [...], "overrides": {}}`, where `rules` lists the IDs from each selected module's section of the plugin registry (Core, Guards, and Silent degradation always). Add an `overrides` entry for any row whose enforcement genuinely differs in this project — a manifest asserting checks that do not exist is worse than none. Prove it resolves: `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/render_registry.py" --validate` must pass. The project renders its registry view on demand; it never holds a copy that can drift. Then run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/render_instructions.py" --rules-dir .claude/rules --write` to fill `{{RULES_INDEX}}` in `CLAUDE.md` and generate `AGENTS.md` and `.cursor/rules/dev-kit.mdc` from the module frontmatter (Claude + Cursor + AGENTS by default; add `--targets ...,GEMINI.md` only when the interview selected Gemini). `check_instruction_honesty.py` (C-10) then holds these in sync; `.claude/rules/org.md` is the org constraints block, not a module, and is skipped.
5. `.claude/hooks/guard-local.sh` — copied from `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/guard-local.sh`, executable. This is A11's floor: a self-contained secrets+force-push guard that survives plugin absence. Every other guard is declared **globally by the plugin itself** (`hooks/hooks.json`, A18) and disappears entirely if the plugin is uninstalled — guard-local.sh is what still blocks C-01/C-02 when that happens. Wire it in `settings.json` (step 6) ALONGSIDE the plugin's own guard.sh — A6 proved any exit-2 blocks regardless of order, so double-wiring is safe.
6. `.claude/settings.json` — wires **only** `guard-local.sh` (`PreToolUse`, matcher `Bash|Read|Edit|Write`). Do not add entries for `guard.sh`, `rule-zero.sh`, `done-check.sh`, `format.sh`, `verify-record.sh`, or `session-context.sh` here — **A18: `${CLAUDE_PLUGIN_ROOT}` does not resolve inside a project's own `settings.json`.** A hook command built from it there is silently skipped, never run, not even with an empty value (measured on CLI 2.1.220 — `docs/BACKLOG.md` A18). That is what this step used to tell the scaffolder to write. Those six hooks are now declared once, globally, in the plugin's own `hooks/hooks.json` — the only place the variable resolves — and each one gates itself on `.claude/.framework-state.json` (written in step 7) before doing anything else, so installing the plugin does not silently switch on enforcement in every *other* repo the user has open, only ones this kit has scaffolded. Writing a redundant entry here would either duplicate that global wiring (double subprocess cost, double `.enforcement-log` lines per real deny) or, in the old broken form, do nothing at all. A15's session-telemetry reasoning for `SessionStart` still applies — it is unaffected by where the hook is declared. See `${CLAUDE_PLUGIN_ROOT}/templates/process/ENFORCEMENT.md`.
7. `.claude/agents/*.md` — only the selected agents: `verify-runner` unconditionally, plus `schema-reviewer` / `integration-auditor` / `contract-drift-checker` / `design-critic` exactly when `database` / `data-integration` / `contracts` / any `design-*` module (respectively) is in `decided_modules` — see `references/module-catalog.md` § *Agent Catalog*; no separate interview question. Also write `.claude/.framework-state.json` recording the interview's companion answer and any design bundles selected — the **full initial object**, not just the `companions` key: `{"version": null, "files": {}, "bundles": ["design.tokens", "..."], "companions": {"<name>": {"min_version": "<v>", "why": "<one line>", "source": "<marketplace or URL>"}}}`. `bundles` holds the raw Round 3 design-capability answer (`design.tokens` / `design.verify` / `design.content` / `design.direction` / `design.build` / `design.govern`) independently of which `design-*` module(s) it resolved to — `design.content`, for instance, can be declared with no module behind it, the same way a declared companion is a declaration and not a rules module either. The framework baseline (`version`/`files`) is not recorded until step 11 runs `upgrade.py --apply`, so this file is the only state anything reads until then — and `upgrade.py` must be able to load it without crashing, treating a missing `companions` or a missing `bundles` the same way: absent means empty, never a crash (C1). Files written before this change lack `bundles` entirely; that must resolve to `[]`, not an error. Declare only what the project genuinely relies on: G-06 means an unmet declaration is a finding, so declaring a plugin nobody uses — or a bundle nothing backs — manufactures a permanent false alarm. Verify with `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_companions.py"` before finishing.
7a. **Design artifacts** — only when a design bundle was selected:
   - `design-tokens.json` at the project root: **copy**
     `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/design-tokens.json`, the generated
     single-file seed — colour tiers top-level, every other token file keyed by its
     stem, the one shape that builds at parity with `kit/tokens/` (`/gate` proves it
     on every plugin change). Then replace the `primitive.brand` ramp with the
     project's brand; keep the semantic and component tiers. Never merge
     `kit/tokens/*.json` by hand: a flat merge builds 70 of 320 variables.
   - Prove it with the project's **own** authoring gate — the exact command step 9
     writes into `verify`, from the kit `npm ci` installs (ADR 005):
     ```sh
     K=node_modules/@roofadvisor/dev-kit/kit
     [ -f "$K/scripts/build_tokens.mjs" ] || { echo "dev-kit is not installed — run: npm ci"; exit 1; }
     python3 "$K/scripts/validate_tokens.py" design-tokens.json
     python3 "$K/scripts/validate_contrast.py" design-tokens.json
     node "$K/scripts/build_tokens.mjs" --in design-tokens.json --out src/theme.css --strict
     python3 "$K/scripts/lint_hardcodes.py" src/components
     ```
     `src/theme.css` is the CSS-variable theme (`--color-*`, `--space-*`,
     `--radius-*`, ...) every component, including the worked example below,
     resolves its `var(--...)` references against. `lint_hardcodes.py` refuses an
     empty directory, so write the worked example in this step — before step 9's
     verify first runs, not after.
   - `src/components/`, `public/images/`, `reference/` with `.gitkeep` files
   - One worked example component with its harness —
     `src/components/Button/{Button.tsx,Button.states.html,index.ts}`.
     `Button.tsx` copies from `${CLAUDE_PLUGIN_ROOT}/kit/examples/golden/Button.tsx`;
     `index.ts` is its one-line re-export. **`kit/examples/golden/` ships no
     `.states.html`** — there is nothing there to copy. Generate
     `Button.states.html` instead: a harness that renders the copied `Button`
     (its real `ds-btn` class, `data-variant`, `aria-pressed`, `aria-busy` —
     not a re-styled clone) through all 8 states, in the grid-of-cells shape
     `${CLAUDE_PLUGIN_ROOT}/kit/examples/component-states/button.html` already
     demonstrates. **Golden's `.ds-btn` rules ship as a comment block inside
     `Button.tsx`, not live CSS** — `build_tokens.mjs` above only emits the
     token *variables*, not this class. Extract the comment block's rules into
     `src/theme.css` (appended after the generated variables) and give the
     harness `<link rel="stylesheet" href="../../theme.css">` so it actually
     loads them. Skip either step and the harness still renders — as unstyled
     default browser controls — and the gates score that green: a design
     project whose gates pass over zero harnesses, or over styles nobody
     wired up, is green with nothing proven.
   - `.mcp.json` with the server(s) Round 3's Figma/Notion/Drive answer named,
     seeded from `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/mcp.json.tmpl`.
     **No secrets in it** — every value is `${VAR}` expansion, read from the
     user's own shell at launch, never written here. Remind the user to set
     those variables in step 5's closing report.
   - `npm i -D playwright && npx playwright install chromium`, so the render
     gates resolve a browser rather than reporting SKIPPED.
8. Local stack + `scripts/dev-reset.sh`:
   - Multi-instance project → `docker-compose.multi.yml` (two app instances, nginx round-robin, redis, and a **separate migrate step**) plus `scripts/nginx-lb.conf`. **This is the default.** One instance locally makes every statefulness bug invisible until production.
   - Single-instance project → `docker-compose.yml`, and ADR 002 recording that choice with its reversal cost.
9. `verify` script in `package.json` and/or `Makefile`. For a Node project, also add
   `"@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#v<version>"` to `devDependencies` — the
   version this plugin reports in `installed_plugins.json` — and run `npm ci`: every design and
   registry gate runs from `node_modules/@roofadvisor/dev-kit` (ADR 005), and fails naming
   `npm ci` when it is absent. A project with no `package.json` keeps the registry fragment
   in the scaffold-spec and its honest `SKIPPED`.
10. `.github/workflows/` — `verify.yml`, always, rendered from `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/verify.yml.tmpl` (fill `{{DB_NAME}}`, `{{SETUP_CMDS}}`, `{{VERIFY}}` — same token-fill pattern as `CLAUDE.md.tmpl` in step 2 — so the workflow runs the command step 9 established). `{{SETUP_CMDS}}` is `npm ci` for a Node project (plus `npx playwright install --with-deps chromium` only when the verify command runs render gates): it is the line that puts the kit on the runner, which is what lets the design gate inside `{{VERIFY}}` run for real there rather than skip. If the org profile has `claude_github_app: installed` and `notion_work_db` set, also copy `claude.yml` from `${CLAUDE_PLUGIN_ROOT}/templates/github/claude.yml`, `claude-code-review.yml` from `${CLAUDE_PLUGIN_ROOT}/templates/github/claude-code-review.yml`, and `notion-sync.yml` from `${CLAUDE_PLUGIN_ROOT}/templates/github/notion-sync.yml`; then copy `scripts/notion_sync.py` to `.github/scripts/`.
   Also write `.github/ISSUE_TEMPLATE/bug.yml` and `feature.yml` — structured enough that `@claude` can act on a report directly.
11. **Process layer** — always, regardless of project size:
   - `docs/specs/`, `docs/decisions/`, `docs/log.md`, `docs/intake.md`
   - `docs/LIFECYCLE.md`, `docs/DEFINITION.md`, `docs/ENFORCEMENT.md`, and `docs/TEST_STRATEGY.md` copied from `${CLAUDE_PLUGIN_ROOT}/templates/process/`
   - `tests/hooks_test.sh` copied from the kit, and wired into the verify command
   - `${CLAUDE_PLUGIN_ROOT}/templates/tests/guard_tests.{py,ts}` copied to the project suite — S-01 and S-02 apply to every project
   - `.github/workflows/gates.yml`, copied from `${CLAUDE_PLUGIN_ROOT}/templates/github/gates.yml` — only the jobs whose rules this project holds; delete the rest, a gate for a rule the project does not have will fail confusingly. The gate scripts are **not** copied: the workflow runs them from `node_modules/@roofadvisor/dev-kit/scripts/` (the devDependency from step 9; ADR 005) and fails while `.github/scripts/` holds `check_*.py` copies.
   - `.github/workflows/preflight.yml`, copied from `${CLAUDE_PLUGIN_ROOT}/templates/github/preflight.yml` — asserts required secrets exist before anything depends on them
   - Set the `SINGLE_INSTANCE` repo variable to `1` for single-instance projects, so the statelessness gate does not fire wrongly. A gate that fires wrongly gets disabled, and a disabled gate protects nothing.
   - Run `scripts/upgrade.py --apply` once at the end to record the framework baseline in `.claude/.framework-state.json`. Without it, the first upgrade cannot tell a local customization from a framework change.
   - `.gitignore` entries for `.claude/.session-log`, `.claude/.last-verify`, `.claude/.enforcement-log`, and `.claude/.init-state.json` — local telemetry and working state, not shared
   - `.github/pull_request_template.md` from `PR.template.md`
   - `docs/decisions/001-stack.md` — write the ADR for the stack chosen in this interview. The first decision is always the stack, and it is always worth recording.
12. `README.md` — human-facing, distinct from CLAUDE.md
13. First commit

**Critical:** `CLAUDE.md` loads on every turn. Keep it to the architecture map, the commands, and the non-negotiables. Everything else goes in `.claude/rules/` where it loads only when relevant.

---

## Step 4 — Prove it works

Do not declare done until:

```bash
./scripts/dev-reset.sh   # stack comes up, migrations run, seed loads
<verify command>          # passes on the empty scaffold
git log --oneline -1      # scaffold commit exists
```

If the verify command fails on an empty scaffold, fix the scaffold — never loosen the check.

When all three checks pass, delete `.claude/.init-state.json`. Success is the only thing that deletes it — a failed verify keeps the state so the run stays resumable.

---

## Step 5 — Report

Print the file tree written, the verify command, and **the three things the user must fill in themselves** (credentials, the real schema, the first endpoint). If a design bundle wrote `.mcp.json`, add a fourth: the MCP env vars it expects (`FIGMA_API_KEY` and friends), set in the user's own shell — never in the file. Then stop. Do not start building features.

---

## RETROFIT mode differences

- **Detect before asking.** Read `package.json`, `pyproject.toml`, existing dirs, and any current `CLAUDE.md`. Bring findings to Round 1 so the user is correcting, not typing.
- **Never overwrite an existing `CLAUDE.md`.** Write `CLAUDE.md.proposed` and show a diff.
- **`written_files` tracks only files this init run wrote.** Pre-existing repo files are governed by the retrofit rules above, never by the resume list — resuming must not turn "skip what we wrote" into "overwrite what was already there".
- **Adopt existing conventions** over template defaults. If the repo uses `npm` and 4-space Python indents, the rules encode that. The framework is for consistency going forward, not for reformatting history.
- **Run the verify command first.** If it fails on existing code, report the failures and ask whether to fix or to baseline them — do not silently weaken the config.
- Ask additionally: *"What in this repo currently annoys you, or what does Claude keep getting wrong?"* Those answers become the most valuable rules in the file.

---

## Reference files

- `references/interview-guide.md` — how to read ambiguous answers, follow-ups worth asking
- `references/scaffold-spec.md` — exact file contents per module
- `references/module-catalog.md` — what each rules module contains and what it costs
- `${CLAUDE_PLUGIN_ROOT}/templates/org/ORG.template.yml` — the org profile schema this reads from
