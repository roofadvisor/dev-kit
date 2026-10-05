# dev-kit — Instructions

The complete map of what this plugin installs, what each piece runs and reads, and
where every item came from.

**Two lineages, one plugin:** `dev-kit` 2.0.0 merges `f4d-kit` (interview-driven
scaffolding, composable rules modules, safety hooks, audit agents — 15 skills, all
in-house) with `design-kit` (DTCG tokens, component specs, WCAG verification gates —
17 skills, vendored from plugin87/ux-ui-agent-skills). Every skill declares its
steps, files, and exact commands; there is no hidden behavior. Design capability is
opt-in per project — see *The six design bundles* below. What that buys: a
development-only project's `.claude/rules/` carries none of the design modules —
the cost that actually loads into every turn. All 32 skills' short trigger
descriptions are a fixed cost of installing the plugin at all (~3,423 tokens
total, measured via `claude plugin details dev-kit`), independent of any one
project's bundle choices — see README.

## The flow

Two lifecycles, sharing one rules/hooks/verify substrate. A project typically holds
the development lifecycle, with a design bundle layered on top when it builds UI.

**Development** — full version: `templates/process/LIFECYCLE.md`

| Stage | Skill |
|---|---|
| 0 · Intake | `work-intake` |
| 1 · Spec | `write-spec` |
| 2 · Decide | `decision-record` |
| 3 · Build | `new-module` · `new-integration` · `contract-first` |
| 4 · Review | audit agents — `verify-runner` always; `schema-reviewer` / `integration-auditor` / `contract-drift-checker` when their module is held |
| 5 · Ship | `ship-it` |
| 6 · Learn | `retro` → `promote-rule` |

Setup and upkeep, outside the per-change flow: `org-profile` + `project-init` (once
per company / project) · `repo-builder` (wraps both, for a brand-new repo) ·
`framework-upgrade` + `project-audit` (monthly) · `notion-sync` (the work-tracking
substrate the rest can write into).

**Design** — gates prove correctness; the critic judges taste — in that order, never
one instead of the other:

| Stage | Use |
|---|---|
| 1 · Foundation | `brandkit` · `design-tokens` · `migrate-design-system` |
| 2 · Direction | `apply-aesthetic` · `ux-writing` |
| 3 · Build | `design-component` · `design-code` · `image-to-code` · `prototype` · `redesign` |
| 4 · Verify | `/gate` · `design-qa` · `a11y-audit` · `performance` · `token-build` |
| 5 · Judge & govern | `/critique` · `design-review` · `governance` · `figma-integration` |

> **Playwright prerequisite:** scripts that render (measure_render, verify_states,
> axe_audit, focus-trap/keyboard/RTL/responsive checks) need
> `npm i -D playwright && npx playwright install chromium`. Without it they refuse or
> report SKIPPED — a skipped gate is never a passed gate. Confirmed working end to
> end on a clean-room install: `/gate` genuinely renders through real Chromium and
> reports a real `N/N` line (currently 34/35 — see CHANGELOG.md's `2.0.0` entry for
> the one open finding).

## Development skills (15) — in-house

No external upstream: these originate in `f4d-kit`, this framework's predecessor
plugin, published from the private `f4d/f4d-dev-env-configurator` repo. Source
column is omitted below for that reason, not by oversight — linking a private repo
from a now-public plugin would 404 for every reader, the same mistake this release
removes elsewhere.

| Skill | Job | Runs / reads |
|---|---|---|
| contract-first | Cross-repo contract change: spec → generate → pin → implement | `openapi-typescript` / `datamodel-code-generator` codegen; hands off to `contract-drift-checker` |
| decision-record | Write an ADR — the choice, the alternatives that lost, why | `templates/process/ADR.template.md` → `docs/decisions/NNN-<slug>.md` |
| framework-upgrade | Move a project from an older dev-kit version to current; diff, classify, apply | `scripts/upgrade.py --plugin "$CLAUDE_PLUGIN_ROOT"` |
| new-integration | Scaffold an isolated external-source adapter — fixtures, retry, rate limits | writes adapter/client/mapper/fixtures; updates the canonical-record table |
| new-module | Scaffold a full vertical slice — migration through route, one pass | reads `.claude/rules/` first for house style; writes `migrations/`, tests, seed fixtures |
| notion-sync | Set up / operate the Notion Work DB mirroring GitHub issues and PRs | `scripts/notion_sync.py` · `templates/notion/WORK_DB_SCHEMA.md` · `templates/notion/SYNC_ARCHITECTURE.md` · `templates/github/notion-sync.yml` |
| org-profile | Company-level profile every project in that company inherits | `templates/org/ORG.template.yml` → `~/.claude/f4d/orgs/<slug>.yml` |
| project-audit | Audit a repo against the framework — rules, hooks, verify, CI, seed quality | `scripts/session_report.py` · `scripts/upgrade.py` · `scripts/check_companions.py` · `scripts/render_registry.py --validate` · `scripts/check_agents.py` · `scripts/check_statelessness.py`; writes `docs/dev-audit-<date>.md` |
| project-init | Interview, then scaffold/retrofit the full Claude dev environment | `references/scaffold-spec.md` · `references/interview-guide.md` · `references/module-catalog.md`; writes CLAUDE.md, `.claude/rules/*`, hooks, agents, `.claude/.framework-state.json`; calls `org-profile` |
| promote-rule | Move a rule up the enforcement ladder: PROSE → LINT → TEST → GATE → HOOK | `templates/rules/REGISTRY.md` · `scripts/session_report.py` · `templates/tests/` · `hooks/` · `scripts/check_*.py` |
| repo-builder | Entry point for anything new: repo, interview, scaffold, workflows, push | orchestrates `org-profile` → `project-init` → `notion-sync` → `gh repo create` → `templates/github/*.yml` |
| retro | Retrospective that converts what went wrong into rule changes | `scripts/session_report.py` · `docs/specs/` · `docs/decisions/` · CHANGELOG.md; calls `promote-rule`; appends `docs/log.md` |
| ship-it | Prepare work for merge/release — audits, Definition of Done, rollback, changelog | project verify command; the audit agents; `templates/process/DEFINITION.md` · `templates/process/PR.template.md` |
| work-intake | Triage a request into the right lane — classify, size, route | the org's Notion Work DB or a GitHub issue; routes to `write-spec` or `decision-record` |
| write-spec | Numbered project spec before building — problem, criteria, non-goals | `templates/process/SPEC.template.md` · `templates/process/DEFINITION.md` → `docs/specs/NNN-<slug>.md` |

## Design skills (17) — [plugin87/ux-ui-agent-skills](https://github.com/plugin87/ux-ui-agent-skills)

The 7 formerly-standalone aesthetic skills (clean, modern, friendly, premium,
refined, spacious, enterprise) are retired as separate skills and now inlined inside
`apply-aesthetic`'s own catalog — see that row.

| Skill | Job | Runs / reads | Source |
|---|---|---|---|
| a11y-audit | WCAG 2.2 audit, criterion-referenced | `kit/accessibility/*` · measure_render, verify_states, contrast.py | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/a11y-audit) |
| apply-aesthetic | Apply an archetype or one of 138 named systems by resolving it into tokens | `kit/taste/aesthetic-systems.md` — 7 archetypes inlined and bundled; the other 131 named-brand entries link to Claude Design / the raw kit archive, not bundled here | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/apply-aesthetic) |
| brandkit | Brand token system from a brief | writes DTCG tokens · accuracy_report | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/brandkit) |
| design-code | Production code, any framework | `kit/frameworks/adapter-protocol.md` · verify_states, accuracy_report | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/design-code) |
| design-component | Component spec to the house quality bar | `kit/components/*` · states harness (verify_states, axe_audit, measure_render, verify_focustrap) | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/design-component) |
| design-qa | Stand up / run QA gates, wire CI | `kit/workflows/design-qa.md` · validate_tokens, validate_contrast, lint_hardcodes, measure_render | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/design-qa) |
| design-review | 6-dimension heuristic critique | `kit/workflows/design-review.md` · `kit/taste/design-taste.md` — analysis only | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/design-review) |
| design-tokens | Generate / audit DTCG 3-tier tokens | `kit/tokens/*` · validate_tokens, contrast.py | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/design-tokens) |
| figma-integration | Tokens ↔ Figma Variables | `kit/workflows/figma-integration.md` · `kit/tokens/theming.json` · Figma MCP when connected | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/figma-integration) |
| governance | SemVer, deprecation, contributions | `kit/workflows/governance.md` | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/governance) |
| image-to-code | Screenshot → token-driven code | measure_render, lint_hardcodes, design_systems.py | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/image-to-code) |
| migrate-design-system | Bridge M3 / HIG / Fluent / shadcn… | `kit/design-systems/crosswalk.md` + `interop-protocol.md` | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/migrate-design-system) |
| performance | Core Web Vitals | `kit/workflows/performance.md` · `kit/tokens/motion.json` | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/performance) |
| prototype | Fidelity ladder + validation plan | `kit/workflows/prototyping.md` | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/prototype) |
| redesign | Upgrade existing UI surgically | `kit/workflows/redesign-audit.md` · slop_tells, lint_hardcodes | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/redesign) |
| token-build | Tokens → platform artifacts | build_tokens.mjs · `kit/workflows/token-build.md` | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/token-build) |
| ux-writing | UI copy and voice | `kit/content/voice-tone.md` · `kit/accessibility/i18n-rtl.md` | [↗](https://github.com/plugin87/ux-ui-agent-skills/tree/main/.claude/skills/ux-writing) |

## Commands (2) + agents (5)

| Item | What it does | Source |
|---|---|---|
| `/gate` | accuracy_report.mjs — every objective design gate, all-or-nothing | [↗](https://github.com/plugin87/ux-ui-agent-skills/blob/main/.claude/commands/gate.md) |
| `/critique` | Renders the work, dispatches `design-critic` to argue rejection — after gates, never instead | [↗](https://github.com/plugin87/ux-ui-agent-skills/blob/main/.claude/commands/critique.md) |
| design-critic | Adversarial senior critic — taste verdicts the gates cannot give; selected whenever any `design-*` module is held | [↗](https://github.com/plugin87/ux-ui-agent-skills/blob/main/.claude/agents/design-critic.md) |
| verify-runner | Runs the project verify command, returns only the failures — selected unconditionally | in-house |
| schema-reviewer | Reviews migrations and schema changes — selected when `database` is held | in-house |
| integration-auditor | Audits external-source adapters (retry, timeout, rate-limit, fixtures) — selected when `data-integration` is held | in-house |
| contract-drift-checker | Compares handlers/webhooks against the pinned contract spec — selected when `contracts` is held | in-house |

## Hooks (4 events, 6 scripts) — in-house

Declared once, globally, in `hooks/hooks.json` (`${CLAUDE_PLUGIN_ROOT}` does not
resolve inside a *project's* own `.claude/settings.json`, so plugin-level is the only
place a hook built from it actually runs). Every script's first move is
`hook_opted_in()` (`hooks/_parse.sh`): it exits 0 immediately unless the current repo
has `.claude/.framework-state.json` — written by `project-init` and `upgrade.py` to
every repo this kit has actually touched. Harness-only: no model context cost.

| Event | Script | What it does |
|---|---|---|
| SessionStart | `session-context.sh` | Writes `.claude/.session-log` — the evidence `session_report.py`, `/retro`, and `/promote-rule` run on |
| PreToolUse (Bash\|Read\|Edit\|Write) | `guard.sh` | Hard-blocks dangerous commands (secrets, force-push, …) — exit 2, stderr returned to Claude |
| PreToolUse (Write) | `rule-zero.sh` | Blocks a new near-duplicate file when a canonical home already exists for that category |
| PostToolUse (Edit\|Write) | `format.sh` | Best-effort auto-format of changed files (ruff / prettier) — never blocks |
| PostToolUse (Bash) | `verify-record.sh` | Records a verify run that passed: a verify or test entrypoint whose exit status nothing after it can mask, in the session's own worktree |
| Stop | `done-check.sh` | Refuses a silent "done" when source changed after the last passing verify: once per stop (the retry passes), never mid-merge, judging the session's own worktree |

## The six design bundles

`/project-init`'s Round 3 asks which design capabilities a project needs, in one
question covering all six. A capability adds a rules module only when it has
project-level rules of its own to hold; otherwise its skill(s) read doctrine straight
from `${CLAUDE_PLUGIN_ROOT}/kit/` when invoked. Full mapping and the dependency rule:
`skills/project-init/references/module-catalog.md`.

| Bundle | Module(s) it adds | Notes |
|---|---|---|
| `design.tokens` | `design-tokens` | Token tiers, theme resolution, type scale, spacing, motion |
| `design.verify` | `design-a11y` | WCAG 2.2 AA, the eight states, keyboard, RTL — this *is* the verification layer |
| `design.content` | — | UX-writing doctrine lives in `kit/content/voice-tone.md`, read directly by `ux-writing` |
| `design.direction` | — | Resolves through the token system (`apply-aesthetic`); needs `design.tokens`, adds nothing beyond it |
| `design.build` | `design-components`, `design-handoff` | Anatomy/variants/states/the 8 code-output rules, plus the handoff checklist; needs `design.tokens` |
| `design.govern` | — | SemVer, deprecation, contribution workflow live in `kit/workflows/governance.md`; needs `design.verify` |

`design-critic` (the agent) is selected whenever any of `design-tokens` /
`design-a11y` / `design-components` / `design-handoff` is held — i.e., whenever any
bundle that adds a module is selected.

## Rules modules (25)

Composable `.claude/rules/*.md`, copied in by `project-init` per what the interview
justified — every unneeded module is context Claude burns on every relevant turn.
Full trigger/sizing guidance: `skills/project-init/references/module-catalog.md` ·
enforcement status per rule: `templates/rules/REGISTRY.md`.

**Always-on (4):**

| Module | Adds |
|---|---|
| `core` | Git discipline, commit format, verify-before-commit, no-secrets |
| `guards` | Red-then-green, guard hygiene, where a rule belongs |
| `response-format` | Lead with the answer, bullets over paragraphs, evidence inline, no narration |
| `silent-degradation` | No degrade-to-default, catch→[] trap, guess lists, hardcode boundary, raw ids |

**Selected by the interview (21):**

| Module | Adds |
|---|---|
| `api` | Error envelope, validation at the boundary, status codes, versioning, pagination |
| `blockchain` | Foundry, gas snapshots, CEI ordering, fork testing, no broadcast from agent |
| `capability-parity` | Consumer enumeration, UI-as-proof, row-vs-call failure, preview/execute parity |
| `contracts` | Spec-first, generated types only, version pinning, drift gate |
| `data-integration` | Adapter interface, recorded fixtures, retry/backoff, rate limits, canonical-record reconciliation |
| `database` | Migration policy, naming, indexes, no raw SQL in handlers, N+1 |
| `dataprotection` | PII inventory, no PII in logs/keys/URLs, retention, redaction in fixtures |
| `design-a11y` | WCAG 2.2 AA, the eight states, keyboard, RTL |
| `design-components` | Anatomy, variants, states, error/empty states, the 8 code-output rules |
| `design-handoff` | Handoff checklist, component Definition of Done |
| `design-tokens` | Token tiers, no hardcoded values, theme resolution, type scale, spacing, motion |
| `determinism` | JCS canonicalization, golden fixtures, forbidden fields in hashed payloads, versioned hash paths |
| `keysafety` | Hard blocks on keys, mnemonics, mainnet RPC (auto with `blockchain`) |
| `livesystem` | Prod is read-only to agents, migration notes required, no schema change without plan |
| `money` | Decimal only, splits sum exactly, idempotency keys, property tests, never trust client price |
| `observability` | Structured logs, correlation IDs, no payload logging, health endpoints |
| `python` | uv, ruff, strict mypy, no bare except, Decimal over float |
| `statelessness` | No module-level state, no in-process locks/schedulers, nothing on local disk, migrations not at boot |
| `storage` | Bucket layout, key naming, presigned URLs, content-type, size limits, no PII in keys |
| `typescript` | strict tsconfig, no `any`, no default exports, zod at boundaries |
| `webhooks` | HMAC before parse, constant-time compare, 200-fast + async, event_id dedupe, replay window |

## Divergence, audit, license

`kit/` carries ~40 fixes over upstream `2ffb677`, produced under 13 adversarial review
rounds ([roof-club PR #91](https://github.com/roofadvisor/roof-club/pull/91), private) —
full-system token build, honestly-failing render gates, group-opacity compositing,
consumed-name closure. The `f4d-kit` half is native to this repo's own predecessor,
not vendored. Details: [PROVENANCE.md](PROVENANCE.md) · [LICENSE](LICENSE).
