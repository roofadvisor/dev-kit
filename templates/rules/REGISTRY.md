# Rule Registry

Every rule this framework holds, with an ID, the layer it *should* live in, and
what enforces it **today**. A rule being unenforced is a tracked state, not a gap
in the documentation.

## Why this file exists

The failure it prevents: a rule is written down, everyone agrees it is correct,
nobody notices it is only prose, and it never fires. Documenting a rule and
enforcing a rule are two different acts. This registry keeps the difference
visible.

## Status vocabulary

| Status | Means |
|---|---|
| `HOOK` | A hook exits 2. Cannot be ignored. |
| `TEST` | A test fails the build. Cannot be ignored. |
| `GATE` | A CI job fails on it. Cannot be ignored. |
| `AGENT` | An audit agent reports it. Advisory — a human must act. |
| `LINT` | The linter or type checker catches it. |
| `PROSE` | Written down only. **Will eventually be ignored.** |
| `JUDGMENT` | Correctly prose — mechanising it would produce false positives. |

`PROSE` on a mechanisable rule is a **known debt**, and every one carries a
promote-when trigger. `JUDGMENT` is a finished state.

---

## Core

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| C-01 | Never commit `.env`, keys, credentials | HOOK | **HOOK** | done |
| C-02 | Never force-push a shared branch | HOOK | **HOOK** | done |
| C-03 | No destructive SQL from an agent session | HOOK | **HOOK** | done |
| C-04 | Verify passes before every commit | HOOK | **HOOK** (`done-check`) | done |
| C-05 | One canonical home per concept — no `V2`/`-final` variants | HOOK | **HOOK** (`rule-zero`) | done |
| C-06 | Branch per unit of work, conventional commits | LINT | **GATE** (`check_commits`) | done |
| C-07 | Change the smallest surface that solves the problem | JUDGMENT | JUDGMENT | — |
| C-08 | Never delete a test to make a build pass | TEST | **GATE** (`check_test_count`) | done |
| C-09 | No destructive filesystem commands from an agent session | HOOK | **HOOK** | done |
| C-10 | Instruction files stay in sync with the rule modules | GATE | **GATE** (`check_instruction_honesty`) | done |
| C-11 | No npm install through a linked `node_modules` — `npm ci` empties the tree the link points at | HOOK | **HOOK** | done |
| C-15 | A partial output is a broken output — no placeholders, deliver all N | LINT | **PROSE** | open |

## Guards

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| G-01 | A guard that passed on its first run has proved nothing — break it, see red, restore | JUDGMENT | PROSE + DoD | — (process, not code) |
| G-02 | Every hook has a fail-loud case in the harness | TEST | **TEST** (`tests/hooks_test.sh`) | done |
| G-03 | A guard that cannot evaluate its input must block, not allow | TEST | **TEST** | done |
| G-04 | Unguardable residuals are named explicitly | JUDGMENT | PROSE + DoD | — |
| G-05 | Improving a fixture must not delete a case it expressed | TEST | **GATE** (`check_fixtures` case-diff) | done |
| G-06 | A rule delegated to a companion plugin is only enforced while that plugin is installed | TEST | **TEST** (`tests/companions_test.sh`) | done |
| G-07 | A selected audit agent enforces nothing once its `.claude/agents/*.md` file is missing | TEST | **TEST** (`tests/agent_presence_test.sh`, `scripts/check_agents.py`) | done |

## Silent degradation

The failure class that survives review. Highest-value column in this file.

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| S-01 | Assert a collection is non-empty before asserting over it | TEST | **TEST** (`templates/tests/`) | done |
| S-02 | Never render a raw identifier in user-visible output | TEST | **TEST** (`templates/tests/`) | done |
| S-03 | `catch → []` passes every downstream "is anything missing" gate | TEST | **GATE** (`check_catch_empty`) | done |
| S-04 | A new value/type/shape must fail a check, never degrade to a default | TEST | PROSE + template helper (`assertNever` ships, nothing requires its use) | eslint `switch-exhaustiveness-check` (TS) / mypy strict enum handling (py) wired into the scaffold verify |
| S-05 | One canonical resolver per question — no two guess lists | GATE | PROSE | duplicate-constant-list scan in CI |
| S-06 | Do not infer what the source already stated | JUDGMENT | PROSE | — |
| S-07 | A pure function must not fetch | LINT | **GATE** (`check_pure_imports`) | done |
| S-08 | Cross-check load-bearing numbers against a second source | JUDGMENT | PROSE + DoD | — |
| S-09 | Account data read live; contract data may be a labelled constant | JUDGMENT | PROSE | — |

## Capability parity

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| P-01 | Contract change enumerates and aligns every consumer in the same change | GATE | **GATE** (`gates.yml`) | done |
| P-02 | An unconsumed capability renders disabled-with-reason | TEST | PROSE | project has a UI — then required |
| P-03 | Row-level problem blocks the row; only call-level fails the call | TEST | PROSE | project processes batches — then required |
| P-04 | Preview and execute produce the same request set | TEST | PROSE | project has a dry-run mode — then required |
| P-05 | Load and failure paths ship with the change | JUDGMENT | PROSE + DoD | — |

## Design

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| DS-01 | No hardcoded colour, size, or timing — every value is a token | GATE | **GATE** (`accuracy_report.mjs` → `lint_hardcodes`) | done |
| DS-02 | A component never reads a primitive token | GATE | PROSE | a primitive-token-reference check, wired into an automatic gate |
| DS-03 | Every token has a light and a dark value | GATE | PROSE | a per-token light/dark completeness check, wired into an automatic gate |
| DS-04 | Text meets WCAG 2.2 AA in both themes, measured not assumed | GATE | **GATE** (`accuracy_report.mjs` → `verify_states`, `validate_contrast`) | done |
| DS-05 | Every interactive component ships all eight states | GATE | PROSE | an eight-state completeness check, wired into an automatic gate |
| DS-06 | Every interactive component has a rendered state harness | GATE | PROSE | a rendered-harness-existence check, wired into an automatic gate |
| DS-07 | Destructive actions wear the danger token everywhere | GATE | **GATE** (`accuracy_report.mjs` → `lint_intent`) | done |
| DS-08 | Motion respects prefers-reduced-motion with no content loss | GATE | **GATE** (`accuracy_report.mjs` → `verify_reduced_motion`) | done |
| DS-09 | A design change has a SemVer level and a changelog entry | JUDGMENT | PROSE | — |

## Database

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| D-01 | Every FK has an index | GATE | **GATE** (`gates.yml`) | done |
| D-02 | No `NOT NULL` on a populated table in one step | GATE | **GATE** | done |
| D-03 | No drop/rename in the release that stops writing | GATE | **GATE** | done |
| D-04 | Money columns are `numeric`, never float | GATE | **GATE** | done |
| D-05 | Migrations reversible, or documented as not | TEST | **TEST** (`rollback_test`) | done |
| D-06 | No raw SQL in route handlers | LINT | **GATE** (`check_raw_sql`) | done |

## Integrations

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| I-01 | No test calls a live third-party API | GATE | **GATE** (`gates.yml`) | done |
| I-02 | Four fixtures per adapter: happy, empty, rate-limited, malformed | GATE | **GATE** | done |
| I-03 | Every fixture carries `recorded_at`; stale ones fail | GATE | **GATE** (`check_fixtures`) | done |
| I-04 | Timeout on every outbound call | GATE | **GATE** | done |
| I-05 | Retry only 429/5xx, with backoff and jitter | AGENT | AGENT | lint rule if it recurs |
| I-06 | Ingestion is idempotent on re-run | TEST | PROSE | required once a sync exists |
| I-07 | Documented per-field precedence when sources overlap | JUDGMENT | PROSE + spec | — |

## Contracts

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| K-01 | Types generated from the spec, never hand-written | GATE | **GATE** | done |
| K-02 | Consumers pin a contract version | GATE | **GATE** (`check_contract_pin`) | done |
| K-03 | No consumer more than one major behind | GATE | **GATE** | done |
| K-04 | Shared shape changes start in the contract repo | JUDGMENT | PROSE | — |

## Keysafety

Enforced by `guard.sh` since 1.0; unregistered until 1.18.0 — surfaced by the
A10 fire log's `UNREGISTERED` bucket, which exists to catch exactly this.

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| KS-01 | No transaction broadcasting from an agent session | HOOK | **HOOK** | done |
| KS-02 | No mainnet RPC from an agent session — local or forked chains only | HOOK | **HOOK** | done |

## Money

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| M-01 | `Decimal` or minor units; float banned in currency paths | GATE | **GATE** (`gates.yml`) | done |
| M-02 | Splits sum to exactly the total | TEST | PROSE | project moves money — then required |
| M-03 | Idempotency key on every charge, refund, payout | TEST | PROSE | project moves money — then required |
| M-04 | Never trust a client-supplied price | TEST | PROSE | project moves money — then required |

## Determinism

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| T-01 | Canonicalize (JCS) before hashing | TEST | PROSE | project hashes — then required |
| T-02 | Golden fixture per hash-producing function | TEST | PROSE | project hashes — then required |
| T-03 | Hash path changes get a new version, never an edited fixture | GATE | PROSE | fixture-immutability check |
| T-04 | No timestamps, uuids, paths, or floats inside a hashed payload | TEST | PROSE | project hashes — then required |

## Statelessness

Works on one instance, fails intermittently on two. Structurally invisible
because every environment before production is single-instance.

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| ST-01 | No module-level mutable state (cache, store, registry) | GATE | **GATE** (`check_statelessness`) | done |
| ST-02 | No in-process lock where two instances could both enter | GATE | **GATE** | done |
| ST-03 | No in-process scheduler — external, or leader election | GATE | **GATE** | done |
| ST-04 | Nothing on local disk outlives a request | GATE | **GATE** | done |
| ST-05 | Migrations never run at app boot | GATE | **GATE** | done |
| ST-06 | Sessions in a signed token or a shared store, never memory | GATE | **GATE** | done |
| ST-07 | Rate limits in a shared store — N instances must not mean N× the limit | GATE | **GATE** | done |
| ST-08 | Local dev runs two instances by default | JUDGMENT | **SCAFFOLD** (`docker-compose.multi.yml`) | done |
| ST-09 | A cross-instance test exists: write on A, read on B | TEST | **TEST** (`statelessness_test.py`) | done |
| ST-10 | Graceful shutdown — stop accepting, finish in flight, release locks | TEST | PROSE | project runs >1 instance — then required |
| ST-11 | `/healthz` and `/readyz` mean different things | TEST | PROSE | project is behind a load balancer |
| ST-12 | Every write path idempotent or carries an idempotency key | TEST | PROSE | project has retries or webhooks |
| ST-13 | A cache miss is correct, never merely slower | JUDGMENT | PROSE | — |
| ST-14 | Sticky sessions are a declared workaround, never a design | JUDGMENT | PROSE | — |

## Operations

| ID | Rule | Should be | Today | Promote when |
|---|---|---|---|---|
| O-01 | Repo rules load regardless of session cwd | HOOK | **HOOK** (`session-context`) | done |
| O-02 | Rollback step written before merge | JUDGMENT | PROSE + DoD | — |
| O-03 | Rollback rehearsed, not merely written | TEST | **TEST** (`rollback_test`) | done |
| O-04 | Production credentials never enter an agent session | HOOK | **HOOK** | done |
| O-05 | Structured logs; never log payloads, PII, or credentials | GATE | **GATE** (`check_log_hygiene`) | done |
| O-06 | Docs-only changes skip the full CI gate | GATE | **GATE** (path filters) | done |
| O-09 | Technical answers are led by the result, bulleted, and evidence-backed | JUDGMENT | PROSE | — |

---

## Reading this file

- **IDs are permanent once issued (A9).** Never renumber, split, or reuse an ID — project manifests reference them forever. Superseding a rule takes a **new** ID plus a `Superseded by <new-ID>` note in the old row. `render_registry.py --validate` and `upgrade.py` fail on any reference to an ID that no longer exists.
- **Projects do not copy this file (A2).** A project holds `.claude/rules/manifest.json` (`{"rules": [...], "overrides": {...}}`) and renders its view on demand with `scripts/render_registry.py`. A committed `REGISTRY.md` in a project is stale by definition.
- **`PROSE` on a mechanisable rule is debt.** The promote-when column is its ticket.
- Several rules are `PROSE` because they only apply to some projects. `M-02` matters when the project moves money and is noise otherwise. Those promote at project setup, not globally — `/project-init` turns them on with the module.
- **`JUDGMENT` is finished.** Do not try to mechanize it; you will get false positives and people will disable the check.
- `/retro` updates this file. A rule that was violated gets its status re-examined before anyone restates it.
