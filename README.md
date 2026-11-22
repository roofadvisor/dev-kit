# dev-kit

A Claude Code plugin merging two frameworks into one: interview-driven project
scaffolding, composable rules modules, safety hooks, and audit agents (formerly
`f4d-kit`), alongside DTCG design tokens, component specs, and WCAG
verification gates (formerly `design-kit`). Selectively installable into any
repo or chat; the heavier design cost — rules modules loaded into every turn,
and the scaffolded `design-critic` agent — is opt-in per project via the six
bundles below, so a development-only project never carries design doctrine in
its own context. (All 32 skills' short descriptions are a fixed cost of
installing the plugin at all, independent of any project's bundle choices —
see the token-cost note under *What's inside*.)

## Install

```bash
claude plugin marketplace add roofadvisor/dev-kit
```

```bash
claude plugin install dev-kit@roofadvisor
```

Uninstall or disable per project the same way — nothing persists where it
isn't enabled. Upgrading from either predecessor plugin is not in-place: see
[CHANGELOG.md](CHANGELOG.md)'s `2.0.0` entry for what breaks and the exact
uninstall/reinstall steps.

## What's inside

| Piece | Count | What it does |
|---|---|---|
| Design skills | 17 | a11y-audit, apply-aesthetic, brandkit, design-code, design-component, design-qa, design-review, design-tokens, figma-integration, governance, image-to-code, migrate-design-system, performance, prototype, redesign, token-build, ux-writing |
| Development skills | 15 | contract-first, decision-record, framework-upgrade, new-integration, new-module, notion-sync, org-profile, project-audit, project-init, promote-rule, repo-builder, retro, ship-it, work-intake, write-spec |
| Commands | 2 | `/gate` (run the objective design gates, all-or-nothing) · `/critique` (adversarial design review — after gates, never instead) |
| Agents | 5 | `design-critic` (taste verdicts) · `verify-runner`, `schema-reviewer`, `integration-auditor`, `contract-drift-checker` (audit agents, selected by which rules modules a project holds) |
| Rules modules | 25 | composable `.claude/rules/*.md`; 4 always-on (`core`, `guards`, `response-format`, `silent-degradation`), 21 selected by the `/project-init` interview |
| Hooks | 4 events | `SessionStart`, `PreToolUse`, `PostToolUse`, `Stop` (5 scripts: guard, Rule 0, verify record, session telemetry, done-check) — harness-only; the SessionStart banner is a rules index and the enforcement note, never a second copy of CLAUDE.md |
| Verify marker | 1 script | `scripts/dev-kit-verify-mark.sh -- <verify>`: a project's verify writes done-check's marker itself on exit 0, so a run in a terminal tab counts; `.claude/verify.json` declares the full and a fast verify |
| `kit/` | — | DTCG tokens (14 files), 52 component specs, taste doctrine, WCAG 2.2 checklists, framework adapters, workflows, ~30 local verification scripts |

**Token cost:** `claude plugin details dev-kit` reports ~3,423 always-on tokens —
every skill/command/agent's short trigger description, summed. That figure is a
fixed cost of installing the plugin at all; it does not vary by which design
bundles any given project selects. What *does* vary per project is the rules
modules loaded into every turn in that project's own `.claude/rules/` — that is
the cost the six design bundles actually gate.

**Deliberately excluded:** the 149-entry brand design-system library (1.7 MB). Brand
systems live in Claude Design (claude.ai/design) and in the raw kit archive — the
plugin stays small. `kit/design-systems/` keeps only the crosswalk + interop protocol.

## The six design bundles

Design capability is never all-or-nothing. `/project-init`'s Round 3 asks which
of six capabilities a project needs; each resolves to zero or more rules
modules, and the modules gate which of the 17 design skills, and the
`design-critic` agent, actually apply.

| Bundle | Adds | Notes |
|---|---|---|
| `design.tokens` | `design-tokens` | Token tiers, theme resolution, type scale, spacing, motion |
| `design.verify` | `design-a11y` | WCAG 2.2 AA, the eight states, keyboard, RTL — the verification layer |
| `design.content` | — | UX-writing doctrine read straight from `kit/content/voice-tone.md` |
| `design.direction` | — | Resolves through the token system; needs `design.tokens`, adds nothing beyond it |
| `design.build` | `design-components`, `design-handoff` | Anatomy/variants/states/the 8 code-output rules, plus the handoff checklist; needs `design.tokens` |
| `design.govern` | — | SemVer, deprecation, contribution workflow; needs `design.verify` |

A bundle that resolves to "no module" still does real work — it just reads its
doctrine straight from `${CLAUDE_PLUGIN_ROOT}/kit/` when its skill is invoked,
the same way every skill already does for anything that isn't project-specific.
Full mapping: `skills/project-init/references/module-catalog.md`.

## Full map

**[INSTRUCTIONS.md](INSTRUCTIONS.md)** — every skill, command, agent, hook, and
bundle: what it runs, what it reads, and its upstream source link where one
exists.

## Notes

- Verification scripts that render (`measure_render`, `verify_states`, `axe_audit`, …) need
  Playwright: `npm i -D playwright && npx playwright install chromium`. Without it they
  fail or report SKIPPED honestly — a skipped gate is never a passed gate.
- Paths inside skills/commands use `${CLAUDE_PLUGIN_ROOT}` — the plugin's install root.
- `bash scripts/verify.sh` is the kit's own single verify command. It exits 0
  with every gate clean.
- Provenance, upstream audit, and license status: [PROVENANCE.md](PROVENANCE.md).
