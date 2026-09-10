# BACKLOG — f4d-kit

**Last updated:** 2026-08-13 · **Version shipped:** 1.23.8 · **Status:** all validation green (273/273 test assertions, self-scans clean, all workflows parse)

> **Resume protocol.** If a session ends mid-work: read this file top to bottom,
> then `git log --oneline -5` to see where the last one stopped. Every item below
> is self-contained — ID, why it matters, what to build, how to know it's done,
> and which files it touches. Pick the top unstarted item in the priority list.
> Do not re-derive the reasoning; it is written down here.

---

## 0 — Current state

**Built and validated (as of 2026-08-12):**

| Surface | Count | Notes |
|---|---|---|
| Skills | 15 | repo-builder, org-profile, project-init, project-audit, framework-upgrade, promote-rule, notion-sync, new-module, new-integration, contract-first, work-intake, write-spec, decision-record, ship-it, retro |
| Rules modules | 22 | incl. REGISTRY.md with **77** rules (G-07 added) |
| Hooks | 7 | guard, rule-zero, session-context, done-check, verify-record, format, _parse — **now actually armed in this repo**, see below |
| Gate scripts | 14 | fixtures, contract-pin, guess-lists, rollback, statelessness, commits, raw-sql, pure-imports, catch-empty, log-hygiene, test-count, companions, agents, **instruction-honesty** |
| Agents | 4 | schema-reviewer, integration-auditor, contract-drift-checker, verify-runner — selection is now derived from `decided_modules`, not all-four-always (A20) |
| Verify command | 1 | `scripts/verify.sh` — the kit had none until 2026-08-12, while `/project-audit` demanded one of every repo it audits |
| Process docs | 9 | LIFECYCLE, DEFINITION, CADENCE, ENFORCEMENT, TEST_STRATEGY, + templates |
| Framework ADRs | 3 | plugin distribution, GitHub over Linear, registry-over-enforce-all |
| Tests | **273** | hooks (68) + render_registry (11) + gate_trio (54) + statelessness (4) + conformance (49) + companions (18) + scanner_agreement (8) + agent_presence (34) + notion_sync (27) — measured via `bash scripts/verify.sh`, 2026-08-13 |
| CI | 2 workflows | `gates.yml` (PR) + `main-verify.yml` (push to master) — the kit ran none of its own gates until 2026-08-12 |

**Rule status:** 45 mechanically enforced · 8 tracked debt with triggers · 13 judgment · rest scaffold/agent. (S-04 honestly re-opened in 1.22.2: an unused helper enforces nothing — its promote-when is now toolchain lint integration.)

### What changed on 2026-08-12 — read this before trusting anything above

Four things the kit demanded of every project but had never applied to itself
were closed. Each was found by *doing* the thing, not by reading the docs.

- **The kit now runs its own gates.** `.github/workflows/` did not exist; zero
  commits had ever touched it. `check_commits.py` and `check_test_count.py`
  need `BASE_REF` and had therefore never executed once against this repo.
- **The kit is installable.** `.claude-plugin/marketplace.json` did not exist,
  so every documented install path failed with `Marketplace file not found`.
  Proven working now: `claude plugin marketplace add ./` then
  `claude plugin install f4d-kit@f4d`.
- **The kit's own hooks are armed.** They had never fired here — no
  `.enforcement-log`, no `.session-log`, ever. Wiring them exposed two live
  bugs (see A18).
- **A single verify command exists** — `scripts/verify.sh`, which is also what
  makes `done-check.sh` satisfiable in this repo.

**Installed state:** f4d-kit is installed as a plugin (`f4d-kit@f4d`, scope
user) from the local marketplace. Because the marketplace source is a local
`./` path, `$CLAUDE_PLUGIN_ROOT` resolves to **this working repo**, not to the
versioned cache copy — so edits here are live in the installed plugin. A
consumer installing from GitHub instead gets
`~/.claude/plugins/cache/f4d/f4d-kit/<version>/`. Do not mistake that for a bug.

---

## 1 — Blocked on Ian (not code)

| ID | Item | Detail |
|---|---|---|
| **B-01** | Notion writes rejected — **RoofAdvisor unblocked 2026-08-12, cross-company hub still open** | Three attempts to create `Engineering HQ — All Companies` + Work DB returned "No approval received" — nothing was created, nothing archived. Rather than keep waiting on that approval, RoofAdvisor was switched to `hub_mode: local` and given its own `Engineering Work DB` (data source `76da9458-744e-4f78-bf7c-e726062b9618`) under the existing "Operations OS" page in its own workspace — 7 of the schema's views built (Triage, This week, In flight, By launch, By area, By project, Stale; the 2 hub-only views — By company, Company: `<X>` — don't apply to a single-company DB). Repo options seeded for 6 of the 7 `roofadvisor` GitHub repos (all but `mattpocock-skills`, which looks like an unrelated reference fork). Remaining, lower urgency: the actual cross-company hub (`Engineering HQ — All Companies`, serving Rezon8/F4 Digital/Personal) is still un-created if/when another company needs Notion tracking — check for a pending approval dialog when that's picked back up. Archiving the 4 legacy Trello boards was never scoped to RoofAdvisor and is still untouched. |
| ~~B-03~~ | ~~Push the kit~~ | ✅ Done 2026-08-10 — published as `f4d/f4d-dev-env-configurator` (private). Docs updated to reference the real slug; the plugin/product name stays `f4d-kit`. |
| **B-04** | Secrets | Org-level: `CLAUDE_CODE_OAUTH_TOKEN` (via `claude setup-token`), `NOTION_TOKEN`. Org variable: `NOTION_WORK_DB` (**data source** id, not database id). |
| **B-05** | External Agents waitlist | Notion alpha. Free. Collapses two systems into one if it ships. |

---

## 2 — Architecture findings, open

Full reasoning in `docs/ARCHITECTURE_REVIEW.md`. Condensed to actionable form here.

### A4 — Interview is not resumable · ✅ built 1.11.0, **acceptance proven 2026-08-11**

Kill/re-run protocol executed against v1.16.0 in a scratch repo — both
done-when criteria MET with SHA-verified no-duplication, plus the commit-step
re-entry, delete-on-success-only, and P-04 plan/execute parity. Artifact with
verbatim evidence: `docs/acceptance/2026-08-11-a4-a5-acceptance.md`. Honest
bound recorded there: single-agent single-session run; a fresh-session
interactive run remains the gold proof; rich-scaffold Step-4 verify is O4.

---

### A2 — Registry duplicated per project · ✅ built in 1.15.0 (A9 closed with it)

Shipped 2026-08-11: projects hold `.claude/rules/manifest.json`
(`{"rules": [...], "overrides": {...}}`); rule text and status live only in the
plugin registry; `scripts/render_registry.py` renders the project view on demand
and `--validate` fails on any broken reference. `upgrade.py` reconciles: new
plugin rules surface as candidates (adoption is a decision, not a sync), a
committed project `REGISTRY.md` flags as `STALE-REGISTRY`, and broken manifest
refs exit 1. `REGISTRY.md` now states ID permanence (A9): supersede with a new
ID, never renumber. Proofs: `tests/render_registry_test.sh` — 11 cases, every
fail-loud path seen red (unknown ID, override-on-unheld, empty rules, unknown
key, missing/unparseable inputs, duplicate IDs both sides); live `upgrade.py`
red/green exit-code check. Done-when met: no project `REGISTRY.md`, rendered
view reproduces the stored shape, unknown ID fails the audit.

---

### A10 — No measurement of which rules fire · ✅ built in 1.17.0

Every deny logs `timestamp<TAB>rule_id<TAB>detail` to `.claude/.enforcement-log`
via a shared `log_deny` in `_parse.sh` whose hard property is proven in the
harness: telemetry can never change control flow — an unwritable log still
exits 2. Denies tagged: C-01 (secrets ×3), C-02 (force-push), C-03 (destructive
SQL), C-05 (rule-zero), G-03 (parse failure ×2), and three **UNREGISTERED**
denies (broadcast, mainnet RPC, rm -rf) — the guard enforces rules the registry
holds no row for; the fire report flags them as an honesty gap to resolve.
`session_report.py` prints fire counts on every path (including no-session-log)
with malformed-line disclosure; `/retro` cites the counts. Done-when met.

---

### A5 — Scaffolder has no dry run · ✅ built in 1.12.0

Shipped 2026-08-10: `--plan` runs the same decision path through Step 2, prints
the full plan (files AND non-file side effects), writes nothing — state stays in
memory; persisting it for a later resume is an explicit end-of-plan offer
(1.13.1). RETROFIT defaults to `--plan` first. **Proven 2026-08-11** with the
A4 acceptance run: zero writes after `--plan`, and the predeclared plan
file-list matched `git ls-files` exactly (P-04). Same artifact.

---

### A13 — ST-01 fires on import-time-populated registries · ✅ built in 1.17.1

Option (b), and the boundary is stated honestly: the scanner matches declaration
lines and cannot see cross-file call-site timing, so the sanctioned exception is
a **reviewed annotation** — `stateless-ok import-time registration — <cite the
call-site check>` — documented in `statelessness.md` § *Import-time registries*
and pointed at by the ST-01 finding message. Unannotated declarations fail
regardless of mutation timing (that IS the mechanism); the annotation is a claim
a reviewer verifies. 4-case harness: unannotated red, annotated green, no
blanket allow (line-scoped), message cites doctrine. Bare-annotation enforcement
deliberately stays audit-level — changing the scanner would fail existing
scaffolds' annotations.

---

### A15 — session-context.sh: retire or re-justify · ✅ decided in 1.17.2 — re-scoped, kept

**Evidence:** scratch repo, sentinel rule in `.claude/rules/`, no hook, no
`settings.json`; headless `claude -p` on **2.1.220** returned the sentinel
phrase exactly. Auto-load holds on the deployed CLI.

**Decision:** re-scope, keep. Primary job: **session telemetry**
(`.claude/.session-log` — the evidence layer session_report.py, /retro, and
/promote-rule run on; retiring the hook retires the evidence). The rules-index
injection stays as redundant defense-in-depth for older CLIs and
`--setting-sources` exclusions, and is never to be cited as the reason rules
load. All doctrine sites updated with the evidence.

---

### A17 — guess-list gate misses object-member lists · ✅ built in 1.23.1

Extended `check_guess_lists.py` with a second, name-agnostic detection path
for array-of-object literals: a per-entry property qualifies as an
identifying key purely on shape — present on every entry, string-valued, and
distinct across entries within its own array — never by matching `objectKey`
or any other name literally. Its sorted values then fingerprint exactly like
a flat list would, reusing the same 2+-files duplicate threshold (now a
shared `MIN_MEMBERS` constant rather than the same magic number twice) and
the same CLI-argument exclusion. Red-green measured against a fixture
mirroring the real GHL-MCP `CUSTOM_OBJECTS` shape (two files: a
`label`/`objectKey` variant matching `mcpServer.ts`/`mainReportQueue.ts`, and
a `label`/`objectId`/`objectKey` variant matching `mainReportFixed.ts`, values
taken from the real repo): pre-fix, `check_guess_lists.py` reported "No
duplicate constant lists found" against it (red); post-fix, it blocks and
names the `objectKey` fingerprint duplicated across both files (green) — and
correctly does **not** unify the two files' `label` values, which drift in
the real repo ("Building" vs "Buildings - Roof Records"), proving exact-match
fingerprinting rather than fuzzy overlap. Fail-loud cases proven: an
object-array with no discernible stable key (every column repeats) reports
clean rather than crashing or false-flagging; a file that cannot be read
(dangling symlink) is skipped without masking a real duplicate found
elsewhere in the same walk, matching the pre-existing per-file
read-exception path. Regression check: `bash scripts/verify.sh` run
immediately before and after the `check_guess_lists.py` code change (before
any new test cases were added) produced byte-identical output at 159/159
assertions — the code change alone changes no existing behavior. Six new
cases then added to `tests/gate_trio_test.sh` for the new path (43 → 49,
full suite 159 → 165), all green; the kit's own source still reports clean
post-change, so the extension adds no new false positives against a real
repo.
REGISTRY.md's S-05 row checked: the rule text ("no two guess lists") is
already generic and needed no change. Its Today/Promote-when columns read
PROSE / "duplicate-constant-list scan in CI," but `check_guess_lists.py` has
in fact been wired into `templates/github/gates.yml` and this repo's own
`.github/workflows/gates.yml` all along — that pair is stale and should read
GATE (`check_guess_lists`) / "done," matching the S-03/S-07 rows. Out of
scope for this item (a registry-accuracy defect unrelated to the
object-member heuristic); flagged separately rather than folded in here.

**Addendum — PR #35 review (comment handling):** the automated reviewer found
a real gap in the shipped `OBJARR_RE`: its entry separator was bare
`\s*,\s*`, so any comment sitting between entries broke the match outright
and the array was silently skipped rather than fingerprinted. Not an edge
case — hand-maintained lookup arrays get exactly this kind of per-entry
annotation (`{ id: 'one' }, // first`) for the same copy-paste-prone reason
S-05 exists to catch them in the first place. Reproduced directly with the
reviewer's own shape: pre-fix, `check_guess_lists.py` reported "No duplicate
constant lists found" against a two-file duplicate where each entry carried
a trailing `//` comment; post-fix, exit 1 with the correct fingerprint. Fix:
a new `GAP` fragment (`//` line comments and `/* */` block comments mixed
with whitespace) replaces the bare `\s*` in every gap a comma or bracket
used to own outright — before the first entry, around each comma, after the
last one — while `[^{}]*`'s brace-spanning refusal is untouched, preserving
the conservative "skip rather than mis-parse" contract for the shapes still
deliberately unhandled (nested block comments, a `*/` hiding inside a
string, a comment holding a stray brace). Five new cases added to
`tests/gate_trio_test.sh`, red-then-green against the reviewer's own shapes:
per-entry line comments (plus the same shape in a single file, confirming no
false positive), block comments (one file annotated, the other left plain,
proving the fingerprint rides on entry values rather than comment text or
its presence), a comment leading the array before the first entry (the
second shape the reviewer's "per-entry or leading" phrasing named), and a
green regression guard proving nested-object entries still fail to match,
unchanged. `gate_trio_test.sh` 49 → 54, full suite (`verify.sh`) 165 → 170,
all green throughout; `check_guess_lists.py` still reports clean against the
kit's own source post-change.

**Files:** `scripts/check_guess_lists.py`, `tests/gate_trio_test.sh`

---

### A18 — scaffolded repos have a DEAD enforcement layer · ✅ built in 1.23.0

Shipped the recommended option. `hooks/hooks.json` (new) declares `guard.sh`,
`rule-zero.sh`, `done-check.sh`, `format.sh`, `verify-record.sh`, and
`session-context.sh` **globally, at the plugin level** — the only place
`${CLAUDE_PLUGIN_ROOT}` resolves. Each hook's first move is now
`hook_opted_in()` (`hooks/_parse.sh`): one `git rev-parse`, one `[ -f ]` against
`.claude/.framework-state.json`, `exit 0` before stdin is even read if absent.
Presence, not content, is the whole signal — a corrupted-but-present state file
still counts as opted in (tested), so corrupting the marker can never become a
way to silently disable enforcement the way removing the plugin already could.
`/project-init` now writes **only** `guard-local.sh` into a target's
`settings.json`; the broken `${CLAUDE_PLUGIN_ROOT}` form step 6 used to
describe is gone from `SKILL.md`, and `scaffold-spec.md` now carries the exact
replacement content. **No migration needed** for repos scaffolded before this
fix — every one already has `.claude/.framework-state.json` (written at step 7
or 11), so their hooks start firing the moment their plugin install updates
past this version, with zero changes required in the target repo.

Proof, three ways. `tests/hooks_test.sh`: 56 cases (was 40), with a genuine
red-then-green pair — the gate physically removed (`git stash` on the hook
scripts only, keeping the new tests), the whole new "A18" section drops to
46/10 failing (exactly the 10 cases whose entire point is the gate), restored,
56/0. `tests/conformance_test.sh`: 42 cases (was 29) — the manifest parses,
every command resolves to a real executable script, it matches
`.claude/settings.json`'s hook set, and every declared hook actually calls the
gate, that last one also shown red (one call site removed) then green. And a
live run against a real installed plugin — throwaway marketplace pointing at
the change, real `claude -p` sessions, CLI 2.1.220 (the version the original
bug was measured on) — producing the acceptance-bar artifact itself: an opted-in
scratch repo's `.claude/.enforcement-log` reading `C-01 [withheld —
secret-class deny]` after a real blocked `.env` write, and the identical prompt
against a never-opted-in repo creating the file with no `.claude/` directory
ever appearing. Full transcript: `docs/acceptance/2026-08-12-a18-plugin-declared-hooks.md`.

**Honest bounds.** f4d-kit's own repo now carries `.claude/.framework-state.json`
too, so it does not go dark under the new gate — its hooks stay wired directly
in its own `settings.json` as well (repo-relative, the one case that always
worked), deliberately double-wired alongside the new global declaration (A6:
safe), at the cost of a real deny in *this* repo's own sessions logging twice
instead of once; not fixed, since removing either wiring path trades a real
safety margin for a cosmetic telemetry count. `/project-audit`'s and
`ENFORCEMENT.md`'s prose about plugin-version pinning was written for the old,
never-working absolute-path design and is now slightly imprecise about what a
"version mismatch" means under a globally-declared hook — not corrected here
(out of the stated file scope), flagged for a follow-up. While building the
live proof, `rule-zero.sh` was separately observed to derive its search root
from session cwd rather than the target file's own path, which can
false-positive when a tool call writes outside the current repo entirely —
unrelated to A18, not fixed here.

**Files:** `hooks/hooks.json` (new), `hooks/_parse.sh` (new `hook_opted_in`),
`hooks/{guard,rule-zero,done-check,format,verify-record,session-context}.sh`,
`skills/project-init/SKILL.md`, `skills/project-init/references/scaffold-spec.md`,
`scripts/upgrade.py`, `tests/hooks_test.sh`, `tests/conformance_test.sh`,
`templates/process/ENFORCEMENT.md`, `README.md`, `START_HERE.md`,
`.claude/.framework-state.json` (new, this repo's own opt-in).

**Follow-up (2026-08-13, PR #32 review).** The "unwritable log must never
weaken the deny" fixture in `tests/hooks_test.sh` used `chmod 555` on `.claude`
to simulate a telemetry write failure — root bypasses Unix permission bits
entirely, so under a root CI runner (this repo's own included) the write went
through anyway and the fixture reported green without ever exercising the
property it claims to test. Reproduced without needing literal root: the
identical write that 555 blocks for a normal user goes through fine once
permission bits stop being the obstacle (`chmod 777` — the permission level
root effectively sees, since root ignores permission bits altogether). A
same-content regression harness run in scratch (log_deny no longer swallowing
its own write failure, `deny()` gated on it via `&&`) confirmed the exact
failure mode: the old fixture missed the regression at `chmod 777` (false
green) while catching it correctly at real, non-root 555. Fixed by
pre-creating `.enforcement-log` **as a directory** instead of chmod'ing the
parent: opening a directory for writing fails with `EISDIR`, a type check
`open()` makes on the call itself, independent of uid or permission bits —
confirmed to still block the write at `chmod 777`, and the same regression
harness confirmed the new fixture catches the regression there too. The
fixture now also asserts the write itself failed (path still an empty
directory) rather than inferring it from `guard.sh`'s exit code alone, since a
successful write produces the identical exit 2. Targeted fix, `tests/hooks_test.sh`
only; no application code changed.

---

### A19 — `/project-init` never ships the gates or the secrets preflight · ✅ built in 1.23.2

**Correction to the table below** (kept for the record, since half of it was
wrong): `verify.yml` really had no source — step 10 folded it into the
`templates/github/` list built for `claude.yml`/`claude-code-review.yml`/
`notion-sync.yml`, but `templates/github/` has no `verify.yml`; the repo has
`templates/scaffold/verify.yml.tmpl` instead. But `gates.yml` and
`preflight.yml` were **not** unnamed — step 11 ("Process layer",
`SKILL.md:204-205`) already named both as destinations before this fix. What
they actually lacked was a source citation: every sibling line in that same
step (e.g. `docs/LIFECYCLE.md` "copied from
`${CLAUDE_PLUGIN_ROOT}/templates/process/`") names where it comes from; the
`gates.yml`/`preflight.yml` lines named only the `.github/workflows/`
destination. Grep confirmed neither `templates/github/gates.yml` nor
`templates/github/preflight.yml` appeared anywhere in `SKILL.md` pre-fix — so
the original claim "the registry gates never install" overstated it: the step
existed, the source was merely unstated, which is a real but different bug
(an agent following the step literally has no textual anchor for *where* to
copy from, even though a human skimming the repo would probably guess right).

Original table, for context:

| Workflow | Template exists | Named in step 10 |
|---|---|---|
| `verify.yml` | **no** | **yes** — scaffolder told to write a template that isn't there |
| `gates.yml` | yes | **no** — the registry gates never install |
| `preflight.yml` | yes | **no** — the secrets scan never installs |

**Built:** step 10's `verify.yml` now cites its real source —
`${CLAUDE_PLUGIN_ROOT}/templates/scaffold/verify.yml.tmpl`, rendered the same
way `CLAUDE.md.tmpl` is (`{{DB_NAME}}`/`{{SETUP_CMDS}}`/`{{VERIFY}}` filled) —
and is unconditional, unlike the org-profile-gated `claude.yml`/
`claude-code-review.yml`/`notion-sync.yml` trio. Each of those three also now
cites its own `${CLAUDE_PLUGIN_ROOT}/templates/github/<file>` source instead
of sharing one clause — the shared-list-plus-trailing-source-clause shape is
exactly what let `verify.yml` get mis-scoped into it in the first place.
Step 11's `gates.yml`/`preflight.yml` lines now cite
`${CLAUDE_PLUGIN_ROOT}/templates/github/gates.yml` and `.../preflight.yml`
explicitly, matching step 10's style. Left in step 11 rather than moved to
step 10: they are unconditional/always-on ("Process layer — always, regardless
of project size"), unlike step 10's org-profile-gated trio — moving them would
have blurred a real distinction and duplicated the "always" framing step 11
already states once.

`tests/conformance_test.sh` gained a 6-check section
("SKILL.md names a real, correctly-scoped source for every
`.github/workflows/` output") proving `SKILL.md` cites a real, existing,
correct source path verbatim for `verify.yml`, `claude.yml`,
`claude-code-review.yml`, `notion-sync.yml`, `gates.yml`, and `preflight.yml`
— not merely that the source file exists in isolation, which the pre-existing
"spec-mandated artifacts" check already did and which is exactly why it never
caught this. Red-then-green, `bash tests/conformance_test.sh`: reverting only
the `SKILL.md` fix reproduces all 6 new checks failing against the unmodified
text (`pass=32 fail=6`); restoring the fix turns all 6 green (`pass=38
fail=0`). Full suite via `bash scripts/verify.sh`: 153/153 assertions,
`VERIFY PASSED`. Registry checked: `gates.yml`'s P-01/D-01/I-01/M-01 rows
needed no change — this fix makes them ship reliably, it doesn't change what
they enforce.

**Follow-up (PR #31 review, 2026-08-13):** the six-check section above proved
only that `src_rel` appeared *somewhere* in `SKILL.md`, never that it appeared
*next to* its own `dest` (review permalink
`https://github.com/f4d/f4d-dev-env-configurator/pull/31#discussion_r3771020078`).
Swapping two workflows' source citations left all six checks green, because
each check only did `src_rel not in skill` against the whole file — the exact
mis-scoping this section exists to catch, reproduced through a hole in the
test itself. Verified against the real, unmodified `tests/conformance_test.sh`
(commit `11fe9a5`), not a scratch reproduction: with `gates.yml`'s and
`preflight.yml`'s source clauses swapped in `SKILL.md` (their two lines,
204-205), the pre-fix script still reported `pass=38 fail=0`. A second
mutation swapping `claude.yml`'s and `notion-sync.yml`'s sources — both
packed onto step 10's single shared line — reproduced the same false
`pass=38 fail=0`, showing the gap held even within one line, not only across
lines.

**Fixed:** each check now walks `SKILL.md`'s backtick-quoted tokens in
document order and requires the token immediately after `dest` to cite
`src_rel`, rather than testing the file as a whole. A same-line-only version
was tried first and rejected — `gates.yml`/`preflight.yml` sit on adjacent
lines and the four step-10 workflows share one line, so anything looser than
"the very next citation" still let same-line or adjacent-line swaps through.
Red-then-green against both mutations: the fixed check reports `pass=36
fail=2`, failing exactly the two swapped entries in each case (the other four
untouched pairs stay green) — confirmed against real `tests/conformance_test.sh`
runs, mutating and restoring `SKILL.md` in place, not a standalone reproduction.
Restored, the fixed check reports `pass=38 fail=0` again. Full suite via
`bash scripts/verify.sh`: 153/153 assertions, `VERIFY PASSED` — the fix only
tightens which existing 6 assertions are logically checked, not how many run.

**Files:** `skills/project-init/SKILL.md` (steps 10 and 11), `tests/conformance_test.sh`

---

### A21 — six scanners duplicate the SKIP tuple `_common.py` exists to hold · ✅ built in 1.22.4

Consolidated all seven scanners onto `_common.SKIP_DIRS` (now a `frozenset` so
a genuine local need extends it additively — e.g. `SKIP_DIRS | {"migrations",
"db", "sql"}`, documented inline — instead of hand-copying it; five scanners
carry such an extension). `check_fixtures.py`'s old substring dirpath match
never pruned `dirnames` at all and walked every tree in full; it now prunes
for real from the shared set. Every scanner skips dot-directories by default,
matching `check_statelessness.py`/`check_guess_lists.py`'s prior behavior.
Measured: a fixture of 3 real tests plus 80 phantom files dropped into a
`.cache/` directory took `check_test_count`'s count from **3 → 83** before the
fix and **3 → 3** after (the kit's own repo shows the same class of drift: 13
real cases at the prior tip — the backlog's own baseline, independently
reconfirmed). The new `tests/scanner_agreement_test.sh` — one trigger per
scanner (ST-01/D-06/S-07/O-05/S-03/S-05/I-02/C-08) inside a single shared
dot-directory — read **2 pass / 6 fail** against the pre-fix code (only
statelessness and guess-lists, which already filtered dot-directories, came
back green) and **8 pass / 0 fail** after; wired into `verify.sh`'s harness
loop (147 → 155 assertions), which stays green throughout, and
`check_guess_lists` (S-05, the gate this whole item is about) still reports
zero findings against the kit's own repo post-refactor. REGISTRY.md checked —
no row describes SKIP-directory behavior at the implementation level, so none
needed updating. A17 (guess-list gate misses object-member lists, still open)
touches `check_guess_lists.py` too and should rebase onto this once it lands.

**Files:** `scripts/_common.py`, `scripts/check_{catch_empty,log_hygiene,pure_imports,raw_sql,guess_lists,test_count,fixtures}.py`, `tests/scanner_agreement_test.sh`, `scripts/verify.sh`

---

### A23 — this repo's own hook commands went dark the instant cwd left the repo root · **mid-session drift fixed in 1.23.8** · launch-from-subdirectory **closed via the A18 plugin dogfood opt-in (2026-08-13)** · effort S

**Why:** a reviewer on the already-merged PR #29 pointed out that PR #29's fix
(`${CLAUDE_PLUGIN_ROOT}` → repo-relative `hooks/x.sh`) traded one broken
anchor for another: a repo-relative command only resolves while the spawning
shell's cwd **is** the repo root, and `session-context.sh` itself is written
to explicitly detect and support sessions that don't start there.

**Confirmed live, CLI 2.1.220, `claude -p` (six independent fresh scratch
repos, no shared state between runs):**

1. **Mid-session cwd drift — real, and now fixed.** Session launched at repo
   root (hooks correctly wired); agent runs `cd sub/deep` as an ordinary part
   of its work; the **very next** Bash tool call's `PreToolUse` hook, wired
   with the bare relative form, **never fired** — no error, no log line, ran
   as if no guard existed. The identical hook anchored to
   `${CLAUDE_PROJECT_DIR}` fired correctly both before and after the same
   `cd`. This is the realistic, common-case failure — every session that
   `cd`s into a package or subdir mid-work silently loses `guard.sh` (C-01
   secrets, C-02 force-push, C-03 destructive SQL, C-09 destructive fs),
   `rule-zero.sh` (C-05), and `done-check.sh` (C-04) from that point on.
   **Fixed**: all six commands in `.claude/settings.json` now anchor to
   `${CLAUDE_PROJECT_DIR}` — a real env var Claude Code sets on every hook
   process (`code.claude.com/docs/en/hooks.md`), distinct from
   `${CLAUDE_PLUGIN_ROOT}` (plugin-hook-only; PR #29's finding on that
   variable stands unchanged) and pinned to the repo root regardless of later
   `cd`s.
2. **Session launched from a subdirectory — real, and NOT fixed by
   anchoring.** Four more fresh scratch repos, launched with cwd one or two
   levels below root: `.claude/settings.json` is **never discovered at all**
   — not "fires with a wrong path", genuinely never read, hooks included,
   regardless of whether the command inside it is a bare relative path OR
   already `${CLAUDE_PROJECT_DIR}`-anchored (both forms tested, both silent).
   An inline probe command with **zero path dependency** (`echo ... >>
   /absolute/log`) also never fired, isolating this to settings **discovery**,
   not command resolution. Docs support the asymmetry:
   `.claude/settings.local.json` is explicitly documented to resolve through
   the repo root "so one file covers sessions started in any subdirectory";
   `.claude/settings.json` carries no such documented guarantee, and
   empirically does not walk up. No command-path anchoring can fix a file
   that is never read — the only mitigations are launching `claude` from the
   repo root, or a materially different delivery mechanism (plugin-declared
   `hooks/hooks.json`, which activates via plugin install rather than
   cwd-relative discovery — this is what `fix/plugin-declared-hooks` builds
   for **A18**/scaffolded consumer repos; whether to also adopt it for this
   repo's own dogfood settings is future work, not done here).

**Consequence for `session-context.sh` specifically:** its SessionStart
firing only ever happens once, at true session start — so mid-session
anchoring (item 1) cannot help it at all. A session launched from a
subdirectory now correctly fires none of its guards (same as before this
fix) **and** writes no `.session-log` line for that session — invisible, not
mis-tagged. `session_report.py`, `/retro`, and `/promote-rule` all read that
log; their counts undercount by exactly the sessions this affects. This is
the same "silent gap reads as permission" shape A11 (plugin absence) and A18
(scaffolded repos) already named, for a third trigger.

**REGISTRY.md checked, no row edited:** O-01 ("repo rules load regardless of
session cwd") stays **HOOK (session-context) · done** — correctly, per A15,
because that guarantee is independently satisfied by Claude Code's native
`CLAUDE.md`/`.claude/rules/*.md` auto-load (proven with no hook and no
settings.json at all), and session-context.sh was already documented there as
redundant defense-in-depth, "never to be cited as the reason rules load." The
gap this entry found is in session-context's *other*, primary job
(telemetry), which no existing row claims — nothing to correct, a real gap to
track, hence this entry rather than a REGISTRY.md edit.

**Done-when (item 1, closed):** a hook wired with a bare relative path
demonstrably fails (exit 127) from a non-root cwd; the identical hook
anchored to `${CLAUDE_PROJECT_DIR}` demonstrably succeeds from the same cwd;
every command actually shipped in `.claude/settings.json` is asserted
anchored, generically, as a regression guard. All three met —
`tests/hooks_test.sh` § *settings.json hook command resolution*.

**Closed (item 2), 2026-08-13.** No fix exists at the `.claude/settings.json`
level — but one already existed one layer up and had simply not been credited
here: the A18 plugin-declared hooks (`hooks/hooks.json`) are registered by Claude
Code at plugin-**install** time and fire for every session regardless of cwd,
and this repo committed its own `.claude/.framework-state.json` in the same A18
commit (`bf7bb15`), opting itself into that global path. `hook_opted_in()`
resolves the repo root with a single `git rev-parse --show-toplevel` — cwd-
independent — so `session-context.sh`, once fired, writes a correct
`subdir`-tagged `.session-log` line for a session launched anywhere in the tree.
The earlier "future work, not done here" note in item 2 above predated that
merge and was stale. Locked against regression by `tests/hooks_test.sh` §
*A23 item 2* — four assertions: the dogfood marker is present AND git-tracked;
a subdir invocation of an opted-in repo writes `subdir`-tagged telemetry; the
same invocation goes silent once the marker is removed; and the plugin manifest declares session-context.sh under SessionStart specifically, so the delivery that fires the telemetry cannot be silently re-mapped to another event (a gap a reviewer caught on PR #40) — 64 → 68 hook tests.
**Honest bound:** closure holds whenever the plugin is installed — the normal
dev state, and the installed state recorded in §0. A session in this repo with
the plugin *not* installed still falls back to `.claude/settings.json`, which is
only discovered on a root launch; that narrow residual is a documented
operational constraint, not a live gap.

**Follow-up finding (review on PR #39 itself, same day): anchoring alone was
unquoted, and that is a distinct, worse bug.** A reviewer on PR #39
(discussion_r3776532413) caught what item 1's fix shipped:
`"command": "${CLAUDE_PROJECT_DIR}/hooks/guard.sh"` anchors the path but
never quotes it. `${CLAUDE_PROJECT_DIR}` is a real filesystem path and can
legitimately contain a space (e.g. a two-word macOS account name); Claude
Code executes each hook command with `bash -c "$command"` (the same
mechanism `tests/hooks_test.sh:124` uses to test resolution) — an unquoted
expansion in that context word-splits on whitespace like any other unquoted
shell variable.

*Reproduced, RED, via the identical `bash -c "$cmd"` mechanism:* a scratch
project directory `.../has space/in the path` with `hooks/` symlinked in,
`CLAUDE_PROJECT_DIR` set to it, and the command string `.claude/settings.json`
shipped at the time (pre-quoting) — `${CLAUDE_PROJECT_DIR}/hooks/guard.sh` —
run exactly as Claude Code would run it: `bash: .../has: No such file or
directory`, exit 127. The path silently split at the space; `has` (a
fragment) was the attempted executable.

*Fail-open, proven rather than assumed:* exit 127 is not exit 2. Confirmed
against `code.claude.com/docs/en/hooks.md`: for `PreToolUse` (guard.sh,
rule-zero.sh) and `Stop` (done-check.sh), **exit code 2 is the only exit code
that blocks through the code alone** — "any other exit code doesn't block on
its own … it's a non-blocking error … the action proceeds," and this
explicitly includes the command-not-found case: "when the script path
doesn't exist or isn't executable, the shell exits with a code like 127 …
For most hook events, the action proceeds." Demonstrated directly, not just
cited: the same force-push command (`git push --force origin main`) that the
working *quoted* form correctly blocks (exit 2, stderr `BLOCKED by f4d-kit
[C-02]: force-push is human-only.`) produces exit 127 and **no BLOCKED
message at all** through the unquoted form on the identical spaced path —
guard.sh's own fail-loud logic (G-03) never gets a chance to run, because
bash fails to resolve the executable a layer below guard.sh's own code. The
kit's fail-loud doctrine is implemented correctly *inside every hook
script*; this bug lived one level outside all of them, in the anchoring
string itself, where no script-level check could see it. Six for six —
`session-context.sh`, `guard.sh`, `rule-zero.sh`, `format.sh`,
`verify-record.sh`, `done-check.sh` — were all shipped unquoted, so all six
were exposed. The two that matter most for gating, `guard.sh` (PreToolUse)
and `done-check.sh` (Stop), both fail open under this bug — a real deny
silently becomes a pass. `format.sh`/`verify-record.sh` (PostToolUse) can
never block regardless of this bug, and `session-context.sh` (SessionStart)
likewise never blocks — for those three the cost is lost telemetry/formatting
rather than a defeated gate, but `guard.sh` and `done-check.sh` are exactly
what item 1 above was written to protect.

*Fixed:* every command in `.claude/settings.json` now wraps the entire
expanded path in a literal pair of double quotes —
`"command": "\"${CLAUDE_PROJECT_DIR}/hooks/guard.sh\""`, where the JSON `\"`
decodes to a literal `"` character, so bash sees
`"${CLAUDE_PROJECT_DIR}/hooks/guard.sh"` as a single quoted word regardless
of what the expansion contains. Verified end-to-end, not eyeballed: `python3
json.load` on the file decodes each `command` value to the literally-quoted
string, and that decoded string run through `bash -c` against the same
spaced fixture resolves and executes (exit 0 for the non-denying hooks, the
correct verdict exit code for guard.sh/rule-zero.sh against payloads that
should deny).

*Tests (red-then-green, additive):* `tests/hooks_test.sh` § *settings.json
hook commands survive a project directory containing a space* — builds a
project directory with a literal space in it, symlinks `hooks/` into it,
and: (RED) reconstructs the pre-fix form by stripping the quotes the fix
adds and shows it still word-splits (127) on the spaced path; (GREEN) shows
every command actually shipped resolves (no 127) on the identical spaced
path; (GREEN) shows guard.sh still returns exit 2 with the BLOCKED message
for a force-push payload through the spaced path; (RED) shows the
reconstructed unquoted form silently drops that same deny (127, no BLOCKED
message) on the identical payload and path. The existing generic anchoring
assertion (§ *settings.json hook command resolution*) is tightened to
require the quoted form, not just the anchored one. Confirmed these cases
actually catch a regression, not just describe one: reverted
`.claude/settings.json` to the pre-quoting form, re-ran, watched the five
now-quoting-aware assertions fail exactly as predicted, restored, watched
them pass again. 46 → 50 hook tests; `scripts/verify.sh` green.

**Done-when (item 1, revised):** anchoring alone was insufficient. Full
statement now: every command in `.claude/settings.json` is wrapped in a
literal quoted path, proven to resolve through a project directory
containing a space, and proven not to silently drop a real deny under the
same condition. Met, per the tests above.

**Merge-surfaced follow-up (2026-08-13):** merging this PR forward past
A18/A20/A21/A22 (all merged after this branch was cut) surfaced two more
interaction bugs, found by actually re-running `verify.sh` on the merged
result rather than trusting a clean merge — same discipline as A20's
own merge-surfaced bug above it in this file.

1. `tests/conformance_test.sh`'s hooks.json/`settings.json` drift check
   extracts each hook's filename via `command.rsplit('/', 1)[-1]` — correct
   for the old unquoted form, but the quoting fix above makes the decoded
   string end in a literal `"`, so the extracted name became `guard.sh"` and
   never matched hooks.json's clean `guard.sh`. Fixed: strip surrounding
   quote characters (`chr(34)`, not a literal `"`, since this Python is
   itself embedded in a double-quoted bash string) before taking the
   basename.
2. `tests/hooks_test.sh`'s own spaced-path fixture (`$scwd`, the directory
   the test `cd`s into before invoking each hook) was never `git init`'d and
   never given `.claude/.framework-state.json` — harmless when this test was
   written, since `hook_opted_in()` (A18) didn't exist yet on the branch this
   was built against. Once merged forward past A18, `hook_opted_in()`'s
   `git rev-parse --show-toplevel` on a non-repo `$scwd` fails, opt-in reads
   false, and guard.sh now exits 0 before even reading stdin — the GREEN
   force-push-still-blocks assertion silently passed for the wrong reason
   (never evaluated) until it started failing outright. Fixed: `$scwd` now
   gets `git init -q` and `mkstate` (the same helper every other opted-in
   fixture in this file already uses) before the loop that exercises it.

Both reproduced as real failures on the merged tree first (`hooks
pass=63 fail=1`, `conformance pass=48 fail=1`), not assumed; both green
after their respective one-line fixes. `scripts/verify.sh`: 267 → 269
assertions, VERIFY PASSED.

**Files:** `.claude/settings.json`, `tests/hooks_test.sh`, `tests/conformance_test.sh`

---

### First live test — executed 2026-08-10, findings folded back

Target: `roofadvisor/GHL-MCP` on a scratch clone; deliverable is their PR #1042
(24 findings, 15 danger-annotated proposals; VERIFY green). Kit-side outcomes:
ST-01 false positive → **A13**; audit skill assumed a scaffolded repo → **absent
mode + adoption-recommendation shipped in 1.14.0**; `session_report.py`'s no-log
fallback behaved to spec; the report-document contract (dedicated branch, never
pushed unasked) held in practice. Six PR-review findings on the shipped text →
fixed in **1.13.1**. Review of the audit document itself then caught the kit's
**load-path doctrine stating a false claim** (subdir sessions DO load a root
`CLAUDE.md`; the modules are what never load) — corrected across seven sites in
**1.14.1**, plus a no-markers rule for committed reports. Still owed from the
test: the A4/A5 kill/re-run acceptance proof.

---

### A6 — Hook precedence unspecified · ✅ built in 1.19.0, evidence-backed

Empirical three-run protocol on CLI 2.1.220 (control + blocker-first +
blocker-second): any hook exiting 2 blocks in BOTH orders; a passing hook never
overrides. Contract + design consequence (hooks must be independent) in
`ENFORCEMENT.md` § *Hook precedence*; artifact with the runnable protocol in
`docs/acceptance/2026-08-11-a6-hook-precedence.md`. Honest bound: the bash
harness cannot test harness-level aggregation — the artifact's protocol IS the
test (minutes to re-run); cross-source merge is docs-based with the same
aggregation semantics empirically anchored.

---

### A11 — Plugin absence silently removes all guards · ✅ built in 1.20.0

`templates/scaffold/guard-local.sh`: self-contained (own parser, no shared
libs, no telemetry by design — zero dependencies that could take it down too),
covering C-01 secrets + C-02 force-push + G-03 fail-loud. `/project-init`
copies it into the repo and double-wires it alongside the plugin guard (safe
per A6). `/project-audit` asserts presence/executable/wired AND plugin version
matches the recorded framework state. 4 harness cases red-green.

---

### A9 — Rule IDs have no permanence guarantee · ✅ closed with A2 in 1.15.0

`REGISTRY.md` § *Reading this file* now states permanence (supersede with a new
ID, never renumber); `render_registry.py --validate` and `upgrade.py` fail on
any reference to an ID that does not exist.

---

### A25 — `verify.sh` printed "skipped, need BASE_REF" even when BASE_REF was set · ✅ built in 1.23.7

**Why:** reviewer finding on the already-merged PR that introduced
`scripts/verify.sh` (the kit's single advertised verify command, the thing
`done-check.sh`'s whole enforcement model depends on being trustworthy). The
"skipped locally (need BASE_REF — CI runs these)" section for `check_commits`
(C-06) and `check_test_count` (C-08) printed **unconditionally** — it never
checked whether the caller (CI, or a person who exported `BASE_REF` locally,
exactly as the reviewer described) actually had it set. Proven red in a
scratch clone: a branch with a non-conventional commit subject and a separate
branch that deletes two tests (15 → 13, no `test-removal-ok:` reason) both
reported `VERIFY PASSED` with `BASE_REF` set to a real, resolvable ref — the
identical commits fail `gates.yml`'s PR job. Full protocol with real
command/output pairs: `docs/acceptance/2026-08-13-a25-verify-sh-base-ref-gates.md`.

**Build:** gate the section on `[ -n "${BASE_REF:-}" ]`. When true, run
`check_commits.py`/`check_test_count.py` for real, via the same invocation
`gates.yml` uses (`python3 scripts/check_*.py`, no arguments, from repo root,
inheriting `BASE_REF` from the environment) — report their actual clean/
FINDINGS, same as every other gate script in this file. Only print the skip
message when `BASE_REF` is genuinely absent or empty. An unresolvable
`BASE_REF` (set but pointing nowhere) was deliberately left to the existing
fail-loud behavior already built into both check scripts (G-03) rather than
special-cased in `verify.sh` — confirmed it reports `VERIFY FAILED`, not a
silent pass.

A second bug surfaced by the red-then-green protocol itself, fixed in the
same change: `verify.sh` runs its own six test harnesses and the new
BASE_REF-gated section in one process, and `tests/gate_trio_test.sh` asserts
both "BASE_REF set" and "BASE_REF unset" behavior internally without managing
the variable itself — so a caller's exported `BASE_REF` leaked into the
harness loop and flipped one of its "unset" assertions, a false `VERIFY
FAILED` unrelated to whatever branch was actually being checked. CI never
hits this (the harnesses job and the gates job run on separate runners); a
single local process does. Fixed by running the harnesses loop under `env -u
BASE_REF`.

No `tests/*.sh` harness assertion was added for the primary fix: every
existing harness is itself one of the six things `verify.sh`'s own loop runs,
and `verify.sh` always operates on its own containing repo (`KIT="$(cd
"$(dirname "$0")/.." && pwd)"`) — a new harness that invoked `verify.sh` would
make it call itself recursively. Same bound as A6: the protocol document is
the test, re-runnable in minutes against a disposable clone.

**Files:** `scripts/verify.sh`, `docs/acceptance/2026-08-13-a25-verify-sh-base-ref-gates.md`

---

### A24 — `pip install pyyaml` was named but not pinned, so CI could still diverge · ✅ built in 1.23.6

**Why:** a reviewer flagged the merged PR #26 fix as incomplete. Naming PyYAML
as an explicit dependency stopped the *runner-image* divergence (`gates.yml`
vs `main-verify.yml` disagreeing on what came preinstalled), but an unpinned
`pip install pyyaml` still lets pip resolve whatever release is newest **at
run time** — a new PyYAML landing on PyPI between the PR's `gates.yml` run and
the later `main-verify.yml` run on the merge commit reproduces the identical
"green for a reason nothing in this repo controls" problem one layer down, and
could make an unchanged commit's conformance result depend on when it happened
to be re-run.

**Build:** both workflows now pin the identical version —
`pip install pyyaml==6.0.3` in both `gates.yml` and `main-verify.yml` — plus
the matching local-dev preflight message in `tests/conformance_test.sh`. No
shared lock/constraints file: checked first that this repo has no other
Python dependency (no `requirements.txt`/`constraints.txt`/`pyproject.toml`
anywhere in the tree, and every `scripts/*.py` imports only stdlib + `yaml`),
so a lock file for one package would be its own S-05-shaped debt — two
identical pinned lines, each already carrying its own explanatory comment
about *why* it's pinned, is proportionate instead.

Two repeated pins can still drift apart one file at a time under a future
edit — the comment saying "bump both together" is a request, not an
enforcement, and this repo's own doctrine treats that gap as debt to
mechanize rather than trust. `conformance_test.sh` already parses both
workflow files for other reasons, so it gained one more assertion: both
`pip install pyyaml==` lines must be present and byte-identical, named after
this item so a future failure points back here. `verify.sh`: 147 → 148
assertions (conformance 32 → 33; §0's table corrected alongside — it already
undercounted at 144 before this change, 43+11+39+4+32+18=147, not 144).

**Proof.** Two different classes of claim, two different kinds of evidence:

- *The version pin itself* cannot get red-then-green — a future PyPI release
  can't be forced to exist for a test. Proven by determinism instead: two
  independent `pip install pyyaml==6.0.3` runs in clean virtualenvs both
  resolved to `6.0.3`, and both workflow files grep to the byte-identical pin
  string `pip install pyyaml==6.0.3`. PR body has the exact commands.
- *The new same-pin guard* **can** get red-then-green, and did: temporarily
  edited `main-verify.yml`'s pin to `6.0.2` (leaving `gates.yml` at `6.0.3`),
  ran `conformance_test.sh` — FAILED with `gates.yml pins 'pip install
  pyyaml==6.0.3' but main-verify.yml pins 'pip install pyyaml==6.0.2'`,
  restored, ran again — PASSED. This is the guard-hygiene bar this repo holds
  every new check to (START_HERE.md non-negotiable 1).

**Files:** `.github/workflows/gates.yml`, `.github/workflows/main-verify.yml`, `tests/conformance_test.sh`

---

### A22 — notion-sync templates: five review findings, all real · ✅ fixed in 1.23.1

The automated PR reviewer found five defects across `templates/github/claude-code-review.yml`,
`templates/github/notion-sync.yml`, and `scripts/notion_sync.py` on the
companycam-ghl-integration PR — the first review these three canonical
templates got after being copied byte-identical into three live RoofAdvisor
repos (GHL-MCP, AR-AP, companycam-ghl-integration). `scripts/notion_sync.py`
had never had a test; `tests/notion_sync_test.sh` is its first (14 checks,
wired into `scripts/verify.sh`'s harness loop).

**1 — draft→ready-for-review never triggered review.** `claude-code-review.yml`'s
job already gates on `github.event.pull_request.draft == false`, but `types:`
was `[opened, synchronize]` — `ready_for_review` is a distinct action, not a
`synchronize`, so marking a draft ready with no further commit created no
workflow run at all (the `if:` never even evaluates; there's no run to skip).
Added `ready_for_review` to `types:`. Verified against the actual parsed YAML,
not assumed — PyYAML's SafeLoader resolves the bare `on:` key to the boolean
`True` under YAML 1.1 (confirmed empirically first: `list(doc)` on the
unmodified file prints `['name', True, 'permissions', 'jobs']`, no string
`"on"` at all). Pre-fix `doc[True]["pull_request"]["types"] == ['opened',
'synchronize']`; post-fix includes `ready_for_review`, `opened` and
`synchronize` unchanged.

**2 — PR and issue events for the same work item raced.** `notion-sync.yml`'s
concurrency group was ``notion-sync-${{ github.event.issue.number ||
github.event.pull_request.number }}``. A merge that closes a linked issue
fires both `pull_request.closed` (group `notion-sync-45`) and `issues.closed`
(group `notion-sync-12`) — different keys, no serialization between them,
both able to write the same Notion row concurrently. Changed to a repo-wide
key: `notion-sync-${{ github.repository }}`. Per finding guidance, resolving
a PR's linked issue number at the YAML-trigger level would need an API call
concurrency groups can't make, so this serializes the whole repo instead of
attempting per-issue keys — deliberately not over-engineered; the workflow is
issue/PR events only, low-volume, losing per-issue parallelism costs nothing
real.

**3 — the serious one: PR events corrupted the linked issue's own fields.**
Traced fully, as asked, rather than taken on faith. `OWNED` (line 34 pre-fix)
lists the fields this sync may write but is **never referenced anywhere else
in the file** — decorative, not enforced; that is not where the bug lives.
The bug is in `main()`: GitHub's `pull_request` payload carries no top-level
`issue` key, so every PR event built a *synthetic* issue from the PR itself —
`title`, `created_at`, `labels`, all PR-sourced — and `build_props` sent that
unconditionally, **even when a real, already-correct row existed for the
issue**. A PR whose title, labels, or timestamp differ from its issue (the
normal case — "fix: null check" vs. "Users can't log in") silently overwrote
the issue's own `Title`/`Opened`/`GH Labels` on every open, and again on every
merge or close. Also found while tracing: `Title` is missing from the literal
`OWNED` set even though `build_props` writes it on every real `issues` event —
a documentation-accuracy gap, fixed alongside (one-line addition; `OWNED`
remains unenforced/decorative, that part is unchanged).

Fix splits the write path in two. `build_pr_mirror_props()` (new) handles a PR
event against an *existing* row: only `State`/`PR URL`/`Branch`/`Merged`/
`Commit`/`Synced` — never `Title`/`Opened`/`GH Labels`. For the *no row yet*
case — a PR is the first thing Notion has seen for its issue, a real scenario
(an issue predating the sync, or whose `issues` event sync failed or hasn't
fired yet), not hypothetical — `fetch_issue()` (new) fetches the real issue
from the GitHub API instead of fabricating one. `GITHUB_TOKEN` was already
threaded into the workflow's `env:` block and documented in this script's own
docstring, completely unused until now — strong circumstantial evidence this
was the intended path all along. `fetch_issue` soft-fails (`None`, logged) on
error rather than raising: nothing has been written to Notion yet at that
point, so a bad cross-repo reference or a flaky GitHub call skips one sync
instead of failing the whole job the way a Notion write failure does.

Red-then-green, captured directly — the harness was written and run against
the unmodified files first, not reconstructed after the fact. Pre-fix, the
corruption check failed with `issue-owned fields leaked into a PR-triggered
PATCH: ['Title', 'Opened', 'GH Labels']`, full payload showing the PR's own
title sitting in the `Title` property of issue #12's existing row. The
seed-from-PR check failed pre-fix with `Title='PR-side title for new
issue...', want 'Real GitHub Issue Title'` — the fabrication, caught
concretely. Both green post-fix; 3 more checks cover the existing-row PATCH
still carrying its legitimate PR-owned fields, and an unresolvable issue
reference skipping cleanly instead of fabricating a row.

**4 — closed-but-unmerged PRs stuck "In Review" forever.** `state = "Merged"
if pr.get("merged") else "In Review"` reached the `else` on any non-merged
PR, including abandoned ones — `pull_request.closed` fires on close-without-
merge too, same as on merge. The issue normally stays open and nothing else
ever touches the row again. New `pr_state()`: `merged` → `Merged`; `state ==
"closed"` and not merged → `Closed` — confirmed against the rest of the file
rather than assumed, by reading `build_props`'s existing `elif issue.get
("state") == "closed"` branch, which already uses `"Closed"` for a closed
issue with no PR; open and not merged → `In Review`, unchanged. Red pre-fix
(`got State='In Review', want Closed`), green post-fix; merged-PR and
open-PR cases re-checked as regressions, both still correct.

**5 — unbounded `urlopen()`.** No `timeout=` on the Notion call — a stalled
connection could occupy the job until the runner's own limit, and (per #2,
now repo-wide) block every other notion-sync run behind it. Added
`REQUEST_TIMEOUT = 30` and passed it to every `urlopen()` call, including the
new GitHub one in `fetch_issue()`. `except (urllib.error.URLError,
TimeoutError)` now logs and re-raises the same way `HTTPError` already did.
Confirmed pre-fix, mocked (no live outage needed): a `TimeoutError` from
`urlopen()` propagated with **no stderr diagnostic at all** (only `HTTPError`
was caught) while `urlopen()` itself received no `timeout` kwarg
(`timeout=None` observed directly off the mock call). Post-fix: `timeout=30`
observed on every call, and the diagnostic is logged before the exception
still propagates.

**Housekeeping surfaced along the way:** `check_catch_empty` (S-03) flagged
`fetch_issue`'s two new `except: ... return None` blocks — correctly, per its
own pattern, but both already log before returning, and the only caller
(`if not issue: return`) treats `None` as an explicit checked skip, never as
a found-but-empty issue. Annotated `catch-empty-ok`, matching the existing
convention, rather than restructured working code to dodge a gate. Not a
registry-tracked rule: `templates/rules/REGISTRY.md` grepped clean for
`notion`/`sync` (case-insensitive, whole file) except one unrelated hit —
I-06, generic ingestion-idempotency PROSE for scaffolded *projects*, not the
kit's own sync tooling. Confirmed rather than assumed; this is process-template
code the registry doesn't cover.

`scripts/verify.sh`: 147 → 162 assertions (`tests/notion_sync_test.sh` adds
15, now in the harness loop alongside hooks/render_registry/gate_trio/
statelessness/conformance/companions). All ten gate scripts clean. Top-level
summary table above left untouched deliberately — three other version-bump
PRs (1.22.3, 1.22.4, 1.23.0 ×2) are open concurrently against this same file;
reconciling all of them is one pass, not five.

**Independent check:** ran `integration-auditor` against the diff before
opening the PR (both external calls this file makes — Notion and the new
GitHub fetch — are exactly its remit). It confirmed timeout coverage is
complete and correct on both calls, the `call()`-raises vs.
`fetch_issue()`-soft-fails asymmetry is deliberate and correct (raise
wherever silently continuing could take the wrong branch — e.g. `find_row`
failing closed would misroute into the create path and duplicate a row;
soft-fail only where the caller's response to `None` is a true no-op), and
vendor shapes stay contained to this file. Two things came out of it and were
applied directly: `fetch_issue`'s own `urlopen()` timeout had no dedicated
test (only asserted indirectly through `main()`, which didn't check the
value) — added; and `build_props`/`build_pr_mirror_props` duplicated the
identical `Merged`/`Commit` block — extracted to `pr_merge_fields()`, used by
both. One finding was real but deliberately not fixed here — logged as
**N-04** below rather than folded into this change.

**Addendum, 2026-08-13 — finding 2's own fix was itself wrong; plus one finding this PR never covered.**
Landed on PR #36 (still open at the time), same branch. Two more findings
arrived: a review comment on PR #36 itself, and a parallel, more concrete
finding from roofadvisor/GHL-MCP PR #1075 — the downstream repo that received
this same template and independently found the same root cause. Both point at
finding **2** above.

**Finding 2's repo-wide key was a real fix for a real bug, and also itself a
bug.** Stated plainly rather than glossed over: it swapped one race (a PR and
the issue it closes carrying different concurrency keys) for a different,
equally real one. GitHub's own docs on concurrency groups: "only a single job
or workflow using the same concurrency group will run at a time" and, on what
happens when a new run arrives, "by default, any existing `pending` job or
workflow in the same concurrency group will be canceled and the new queued
job or workflow will take its place" — unconditionally, not gated behind
`cancel-in-progress`, which the same page describes as controlling only
whether "any currently running job or workflow in the same concurrency
group" is *additionally* canceled
(docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs,
fetched and quoted directly, not recalled). Under one repo-wide key, an event
for unrelated issue B arriving while issue A's sync is still pending cancels
A's pending run — with no later event guaranteed to ever correct A's row. The
original A22 writeup even named this trade-off explicitly ("losing per-issue
parallelism costs nothing real") — which was true for the *original* per-
number race, and wrong for what replaced it.

**The fix: a dedicated `resolve` job, keyed on the linked issue.** A
concurrency `group:` expression is evaluated before any job runs, from the
raw event payload, using only GitHub's expression syntax — it cannot itself
regex-parse a PR body to find a linked issue. So `templates/github/
notion-sync.yml` now splits into two jobs. `resolve` (no concurrency block of
its own — read-only, no Notion/GitHub API call, safe to run unbounded in
parallel) invokes `scripts/notion_sync.py resolve-issue`, a new CLI mode that
prints the linked issue number for `GITHUB_EVENT_PATH`'s event (the issue's
own number for an `issues` event, or the PR-body-parsed number for a
`pull_request` event) and sets it as a job output. `sync` now declares
`needs: resolve` and moved its `concurrency:` block from the workflow's top
level down into the job itself:
`group: notion-sync-${{ github.repository }}-${{ needs.resolve.outputs.issue_number }}`.
That move is load-bearing, not cosmetic — confirmed against two separate
GitHub docs pages, not assumed: the top-level `concurrency` key's expression
"can only use `github`, `inputs` and `vars` contexts" (`needs` excluded;
docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions),
while `jobs.<job_id>.concurrency`'s "allowed expression contexts" are
"`github`, `inputs`, `vars`, `needs`, `strategy`, and `matrix`" (`needs`
included; same control-the-concurrency-of-workflows-and-jobs page as above).
A job output could never have reached a top-level `concurrency:` block
regardless of what computed it. The output-passing mechanics
(`needs.<job_id>.outputs.<output_name>`, `jobs.<job_id>.outputs`, writing to
`$GITHUB_OUTPUT`) were confirmed the same way against
docs.github.com/en/actions/using-jobs/defining-outputs-for-jobs. An unlinked
PR (resolve-issue prints nothing) falls back to `unlinked-${{ github.run_id }}`
so it collides with nothing rather than piling every unlinked PR of the repo
into one bucket.

Reasoned precisely about the concrete example roofadvisor/GHL-MCP PR #1075
gave — PR #50 whose body closes #20, and the `issues.closed` event GitHub
fires when #20 is actually closed — and then *ran* `resolve-issue` for both
events plus an unrelated `issues.labeled` for #99, rather than reasoning
about it in the abstract:

| formula | issues#20 | pull_request#50 (closes #20) | issues#99 |
|---|---|---|---|
| pre-A22 (`github.event.issue.number \|\| github.event.pull_request.number`) | `notion-sync-20` | `notion-sync-50` | `notion-sync-99` |
| A22 (`github.repository`, repo-wide) | `notion-sync-roofadvisor/GHL-MCP` | `notion-sync-roofadvisor/GHL-MCP` | `notion-sync-roofadvisor/GHL-MCP` |
| this fix (`github.repository`-`needs.resolve.outputs.issue_number`) | `notion-sync-roofadvisor/GHL-MCP-20` | `notion-sync-roofadvisor/GHL-MCP-20` | `notion-sync-roofadvisor/GHL-MCP-99` |

Pre-A22: #20 and #50 differ (the original race). A22: #20 and #50 match
(that race fixed) but #20 and #99 *also* match (the new bug — unrelated rows
sharing one pending slot). This fix: #20 and #50 still match, and #20 and
#99 now differ. Both properties hold simultaneously, which is the actual bar
("two events touching the same row must serialize; two events touching
different rows must not block each other"), not a re-run of the same
trade-off under a different name.

**Finding 2's regex vocabulary — incomplete, separately.** The linked-issue
regex accepted only `closes|fixes|resolves` — the present-tense-plural forms
— against GitHub's actual nine-keyword vocabulary (`close`, `closes`,
`closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`, all
case-insensitive). Reproduced the reviewer's exact three examples against
the old pattern first: `Fix #123`, `Close #123`, and `Resolved #123` each
returned no match. Extracted the parsing into a single `parse_linked_issue()`
used by both `main()` (unchanged behavior otherwise) and the new
`resolve-issue` CLI mode above, so the two can never drift on which issue a
PR links — one was exactly Finding 1's own requirement ("This regex is also
exactly what Finding 1's job-output resolution step needs to use"). Same
three examples against the new pattern: all three now resolve to `123`.
Negative cases checked deliberately, not just the positive ones: `\b` before
the keyword alternation stops a keyword that is merely a word's suffix
(`unresolved #123`) or infix (`prefixes #99`) from matching, and the existing
required `\s+` before the `#` stops a keyword with trailing text glued to it
(`closest #1`) from matching either — all three verified to still return
`None`.

**Red-then-green, both fixes, captured directly.** All 13 new checks in
`tests/notion_sync_test.sh` were run against the pre-addendum
`scripts/notion_sync.py` and `templates/github/notion-sync.yml` first (`git
stash` of just those two files, new test file left in place) and observed to
fail: the YAML-structure checks with `KeyError: 'resolve'` and `jobs=
['sync']` (no `resolve` job existed yet), the resolve-issue CLI checks with
`KeyError: 'NOTION_TOKEN'` (the mode did not exist; invoking `resolve-issue`
just ran into the top-of-file env var reads and crashed), the keyword-vocab
checks with `AttributeError: module 'notion_sync' has no attribute
'parse_linked_issue'`, and the end-to-end regex check with the literal
pre-fix output, `PR has no linked issue — nothing to sync.` 13 failed, 14
(pre-existing, untouched) passed. Stash popped, same 13 re-run green, 27
passed, 0 failed. `scripts/verify.sh`: 162 → 174 assertions (measured both
ends directly, not assumed from the number above), all ten gates still
clean.

**Not done here, and not claimed:** the actual GitHub Actions run. Per the
kit's own non-negotiables, that's not achievable from an agent session —
the evidence above is expression-semantics citations plus the real
`resolve-issue` subprocess run for every example, not a live workflow
dispatch. Re-propagation to the three downstream repos (including
roofadvisor/GHL-MCP, whose PR #1075 supplied the concrete example) is where
that gets its first live-Actions exercise.

---

### A20 — the agents are scaffolded but not selectable, and never audited · ✅ built in 1.23.0

All three gaps closed together. **(1)** The plan preview's `AGENTS:` line
(`SKILL.md:142`) now reads `verify-runner (always-on)  |  schema-reviewer,
integration-auditor (selected: ...)` — the always-on agent is no longer absent
from what the user approves, and the line now says out loud which agent is
unconditional versus which were derived from an answer. **(2)** Selection is a
rule now, not a vibe: `verify-runner` unconditional; `schema-reviewer` /
`integration-auditor` / `contract-drift-checker` selected exactly when
`database` / `data-integration` / `contracts` is in `decided_modules` — the
pairing `ENFORCEMENT.md`'s honest-audit table already stated, now actually
wired at Step 3.7 and spelled out in `module-catalog.md`'s new *Agent
Catalog* section (no new interview question — reused the modules' own
Q4/Q5/Q7 triggers). **(3)** `scripts/check_agents.py` (new, registered as
**G-07**) derives the expected agent set from which `.claude/rules/*.md` a
repo actually holds and flags any agent file that is missing or
present-but-empty; `/project-audit`'s Enforcement layer runs it right next to
the A11 guard-local check it mirrors in shape. `tests/agent_presence_test.sh`
proves it — 25 cases, red-then-green for all three conditional agents, the
unconditional floor, the empty-file edge case, an unheld-module negative case
(a module NOT held must not require its agent), and two G-03 fail-loud paths
(`.claude/rules` or `.claude/agents` present as a plain file, not a
directory). Wired into `scripts/verify.sh`'s harness loop and gate-script
loop; `bash tests/agent_presence_test.sh` and `python3
scripts/check_agents.py` both run clean against this repo (SKIP — the kit
itself holds no `.claude/rules/`, correctly: it is the plugin source, not a
scaffolded consumer).

**Follow-up (2026-08-13), found by actually running the merged result, not by
inspection:** the claim directly above — that this repo correctly SKIPs — was
true when written and became false the moment A18 merged. A18 gave this
repo's own `.claude/settings.json` a `.claude/.framework-state.json` file too
(self-opting it into its own plugin-declared hooks, an unrelated reason), and
`check_agents.py`'s adoption check used that file's presence as its *only*
signal. Running `bash scripts/verify.sh` against the merged state (not
assumed clean) surfaced `check_agents FINDINGS`: `verify-runner.md` reported
"missing" against a repo with no `.claude/agents/` directory to hold it — the
kit auditing itself as if it were a consumer. Fixed by requiring **both**
`.claude/.framework-state.json` and `.claude/rules/` present together before
evaluating (neither alone is sufficient — see the script's own docstring for
why each one false-positives on its own). `tests/agent_presence_test.sh`
gained 4 cases for this shape specifically (30 → 34): the framework-state-only
SKIP, its message, and a G-03 regression guard proving a corrupted
`.claude/rules` (present as a plain file) still fail-louds rather than being
swallowed into the new SKIP path. Full suite 234/234, `check_agents` clean
against this repo.

**Files:** `skills/project-init/SKILL.md`, `skills/project-init/references/module-catalog.md`,
`scripts/check_agents.py`, `tests/agent_presence_test.sh`, `scripts/verify.sh`,
`skills/project-audit/SKILL.md`, `templates/rules/REGISTRY.md` (G-07).

---

### A26 — no reversible adopt-out; removing an adopted capability is hand-work, not a kit operation · open · effort M

`/project-init` adopts capabilities into a repo and `upgrade.py` reconciles new
versions, but there is **no mirror operation that removes one**. Turning a
capability back off — the A11 guard floor, an instruction-sync managed block, a
gate wired into CI — is manual surgery today, and it has a footgun: the artifact
and its *consumers* come apart. GHL-MCP's `scripts/lib/guardLocal.test.mjs`
spawns `.claude/hooks/guard-local.sh`; **deleting** the guard file turns that
green test red, while **un-wiring** it (removing the `PreToolUse` block from
`settings.json`) leaves the file and the test intact. Disable ≠ delete, and
nothing in the kit encodes that.

Surfaced live 2026-08-20: GHL-MCP's guard was hardened on 2026-08-17 to scan
Write/Edit *body* content (a PEM pasted into `notes.txt` must block) but grew no
exemption for its own source or its test, so every agent edit to the guard was
self-blocked — and the first question that raised was "can we back this out
safely?" The answer is yes (the floor is additive and fail-open, so removal is
non-destructive by construction), but the kit had no *operation* to do it
cleanly, consumer-aware, and recorded.

The gap, precisely: an **adopt-out** that is the symmetric inverse of
`/project-init` — unwire-or-remove atomically, check for consumers the way the
canonical doc-layout promote step checks executable/test consumers before a move
(same discipline, cross-ref A2 + spec 001 do-no-harm), default to *disable* over
*delete* when a consumer exists, and record the removal. Not a safety hole (the
things we adopt are additive and fail-open); the missing piece is a first-class,
reversible, audited operation instead of freehand `rm`. Folded into spec 001's
do-no-harm principle as a standing requirement on every capability the interview
can turn on. Effort M — one skill (`/adopt-out` or a `/project-audit` action)
plus the consumer-scan reused from the doc-layout work.

## 3 — Registry debt (PROSE that should be mechanized)

From `templates/rules/REGISTRY.md`. Each already carries a promote-when trigger.
Use `/promote-rule <ID>`.

**Global — do these regardless of project:**

| ID | Rule | Target | Effort |
|---|---|---|---|
| C-08 | Never delete a test to pass a build | TEST (test-count-decrease check) | S |
| S-03 | `catch → []` trap | LINT (ban empty-collection catch) | M |
| S-04 | New value must fail a check, not default | TEST (exhaustiveness at enum boundaries) | M |
| O-05 | Never log payloads/PII/credentials | GATE (secret-scan + grep) | M |
| G-05 | Fixture edit must not delete a case | TEST (fold into `check_fixtures.py`) | M |

**Project-conditional — turn on with the module at `/project-init`:**

M-02/03/04 (money) · T-01..04 (determinism) · P-02/03/04 (capability parity) ·
ST-10..12 (statelessness) · I-06 (idempotent ingestion)

---

### A27 — a doc-link gate is proposed; the measurement says fix two documents first · open · effort S to measure, M to build

**Where it came from.** The GHL-MCP convergence session filed
roofadvisor/GHL-MCP#1413: `apps/operator-ui/content/operator-documentation.json`
links to a heading that does not exist, GitHub silently lands the reader at the
top of the file, and the link had been dead since it was written. Their proposal
was a checker in this plugin rather than per repo — resolve every relative doc
link and `#anchor`, baseline the known-dead, fail on a new one, baseline only
shrinks. The argument for the plugin is now stronger than they knew: since 2.2.0
the registry gates ship as an npm dependency, so a fourteenth `check_*.py`
reaches every consumer through `npm ci`. One correction to their premise — the
ratchet they cite (`style-debt.json`, retired-surfaces) lives in GHL-MCP, not
here. This kit has no doc rule and no `link` row in REGISTRY.md.

**What the fleet actually holds.** Markdown links only, read through
`git show origin/main:<path>` rather than off disk, with percent-encoding
decoded, `path/file.ts:73` line references stripped, and links inside code
fences excluded:

| repo | links | dead file | dead anchor |
|---|---|---|---|
| GHL-MCP | 196 | 59 | 1 |
| roof-club | 483 | 2 | 3 |
| AR-AP | 5 | 0 | 0 |
| design-kit | 37 | 1 | 0 |

Plus the reported one, which lives in JSON and no markdown scan reaches: five
dead anchors in total, across roughly 720 links and about 9 repo-months of
documentation.

**The dead files are two documents, not a fleet problem.** 48 of GHL-MCP's 59
are one spec (`2026-07-10-result-integrity-error-surfacing-design.md`) pointing
at `src/ghl/planning/…` paths that moved when the repo restructured under
`apps/operator-ui/`. A baseline would freeze that as accepted debt rather than
provoke the repoint, which inverts what a ratchet is for. Fix the document and
about 80% of every finding in the fleet goes with it.

**The case against building it yet is the false-positive rate, and the evidence
is this investigation.** Three separate measurements were wrong before one was
right, each in a way a shipped gate would reproduce:

1. A rate was quoted from a stock with no denominator in time. Dated properly
   against each repo's documentation age it is ~1.6 dead anchors per
   repo-quarter fleet-wide, and roughly four in roof-club, which is the active
   repo. Higher than first claimed, still low in absolute terms.
2. The first scan read the working tree and found 138 dead links in
   `kit/taste/aesthetic-systems.md`. That file is correct in every committed
   revision; the 138 were an **uncommitted, staged modification** in this repo's
   stale main checkout, reverting 131 upstream URLs to relative paths. A gate
   that reads the working tree rather than the revision under review would fire
   on a colleague's desk state.
3. Extending the scan to JSON — which is where the reported defect lives —
   matched DTCG token references (`{radius.md}`) and any prose string containing
   a filename, including this repo's own `hooks.json` comment. Every one of
   those lands on the honest path.

So an honest gate needs: revision-scoped reads, percent-decoding, line-reference
handling, fence exclusion, and a JSON mode that distinguishes an href from a
token reference. That is the same shape as C-01, which produced four false
positives in three days this week, each found only by blocking real work.

**Recommended order.** Repoint the two stale documents; leave the reported
anchor to whoever knows what the imports row-resolution work became, since
repointing it somewhere it also is not would be worse than leaving it; then
re-measure. If dead links regenerate against healthy documents, the gate is
earned and the second measurement names which false positives it must handle.
If they do not, the fix was the documents.

**Registry consequence if built:** a new rule row before any deny, per A9 —
IDs are permanent, and this kit treats an unregistered deny as an honesty gap.

---

## 4 — Opportunities (not defects)

| ID | Item | Value |
|---|---|---|
| O4 | ✅ tier 1 built in 1.21.0 (`tests/conformance_test.sh`: workflows + rendered compose templates parse, executables +x, every registry section resolves as a manifest, every spec-referenced template exists). Tier 2 (behavioral, agent-run) specified in `docs/acceptance/O4-protocol.md` — owns full-spec parity, verify-green-on-empty per combo, and failing-verify-keeps-state; cadence: one rich combo per minor, all five before v2.0 | **The scaffolder is the least-tested component in a system whose premise is testing** |
| O5 | Extract the doctrine (`silent-degradation`, `guards`, `capability-parity`) as a portable artifact | Most valuable content, least tool-coupled; survives a move off Claude Code |
| O6 | Cross-project rule analytics | Fires everywhere → always-on. Never anywhere → delete. One repo only → local problem |
| O2b | `/project-audit` asks the *unanswered* interview questions on an existing repo | Turns retrofit into a partial interview (A4 built — unblocked) |
| O7 | Multi-platform delivery — core + per-platform adapters | The stated goal: let several agent platforms install a native plugin for setup and audit. See below; **O5 is its critical path** |

### O7 — multi-platform delivery (core + adapters)

**The goal (Ian, 2026-08-12):** multiple agent platforms should be able to
install a native plugin and interact with the kit "for setup and audit
purposes" — from a distributed enterprise team down to one person on a personal
project.

**What the split actually looks like.** Most of the kit is already portable; the
coupling is concentrated in one layer:

| Portable today | Claude-Code-specific |
|---|---|
| Doctrine — rules modules, REGISTRY, LIFECYCLE, process templates | `skills/*/SKILL.md` format |
| All 12 gate scripts (plain Python, zero Claude dependency) | `agents/*.md` subagent format |
| Templates — workflows, compose, PR/ADR/spec | `hooks/` event contract + JSON shape |
| The audit *method* | `.claude-plugin/` manifests, `settings.json` |

That is O5 restated with a deadline: extract the doctrine as a portable
artifact, then wrap it per platform. `superpowers` is a worked example in the
plugin cache — MIT, one repo shipping `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, a
`gemini-extension.json`, and adapter references for Codex, Gemini, Pi and
Antigravity.

**Claude Cowork — read the docs 2026-08-12, and this is the decisive constraint.**
Per support.claude.com/en/articles/13345190: Cowork "uses the same agentic
architecture that powers Claude Code, with no terminal required", and a Cowork
plugin is a bundle of **skills, connectors (MCPs), and sub-agents**.

**Hooks are not in that list.** So Cowork can host the kit's advisory half — 15
skills and 4 agents, which is exactly the *setup and audit* surface Ian named —
but it cannot host the enforcement half. On Cowork, "guards, not memos" is
necessarily memos.

That is not a reason to skip Cowork. It is a reason to be explicit about which
half goes where: **skills and agents are the portable interaction surface;
hooks are the enforcement surface and stay in whichever environment does the
actual coding.** A17-era doctrine says a rule delegated to something that cannot
enforce it is unenforced (G-06) — so a Cowork adapter must not claim enforcement
it structurally cannot deliver, and `/project-audit` running there must report
that limit rather than pass silently.

**Open, not yet checked:** whether Cowork can execute the Python gate scripts at
all ("no terminal required" suggests a different execution model). If it cannot,
the audit surface there is agent-driven inspection only, and its findings are
weaker than a gate run — which must be stated in the report, not glossed.

**Depended on A18, now unblocked** (✅ built in 1.23.0, see §2). The
hook-delivery question is settled: hooks travel with the plugin, globally
(`hooks/hooks.json`), gated by a per-repo `.claude/.framework-state.json`
opt-in — not with the project. Still needs O5 before it can move.

---

## 5 — Notion / integration follow-ups

| ID | Item |
|---|---|
| N-01 | Migrate sync to Notion Workers when syncs/webhooks leave beta, **or at the third repo** — whichever first. Full analysis in `templates/notion/SYNC_ARCHITECTURE.md`. Four invariants make it a swap not a rewrite. |
| N-02 | `hub+local` reconciliation is documented (`/notion-sync` Mode 5) but never exercised — no project uses the mode yet |
| N-03 | Work DB `Repo` select options must be added as each repo is wired; sync fails on an unknown option |
| N-04 | `scripts/notion_sync.py`'s `call()` has no retry/backoff on 429/5xx (A22, `integration-auditor`). Not "low volume justifies it" alone — `NOTION_TOKEN` is shared across every repo wired to a given Work DB, and Notion rate-limits per-integration/token, not per-repo, so simultaneous activity across repos can plausibly 429 with no self-healing today. **No longer hypothetical — live now:** RoofAdvisor's `Engineering Work DB` (B-01) exists and is actively wired to 3 real repos (GHL-MCP, AR-AP, companycam-ghl-integration) as of 2026-08-13, sharing one `NOTION_TOKEN`. Worth picking up sooner than "someday" now that there's real concurrent traffic to trigger it, not just a theoretical multi-repo future. **If picked up:** retry only on a definitive 429/5xx response, never on `URLError`/`TimeoutError` where the outcome is ambiguous — and never blindly retry the `POST /pages` create without re-running `find_row()` first, or a retried create after an ambiguous timeout duplicates the row. |

---

## 6 — Priority order

```
NOW      B-01 Notion approval    (blocked on Ian)

NEXT     O4   tier-2 combo runs — ALSO the acceptance test for A18+A19,
              since it is an end-to-end /project-init exercise.

SOON     S-04 promotion: eslint switch-exhaustiveness-check / mypy

LATER    O7   multi-platform delivery (core + adapters) — needs O5 (A18 no longer blocks it)
         N-01 Workers migration — at 3rd repo or beta exit

DONE     A23  item 2 (launch-from-subdirectory telemetry) closed 2026-08-13 via
              the A18 plugin dogfood opt-in + a regression lock; see §2 A23.
```

**A18 shipped in 1.23.0** (see §2) — scaffolded repos now get a live
enforcement layer via plugin-declared `hooks/hooks.json`. **Why A19 is next.**
Its own shape is the same class of gap A18 just closed: step 10 names
workflows that either do not exist (`verify.yml`) or exist but were never
copied (`gates.yml`, `preflight.yml`) — so a freshly scaffolded repo's *hooks*
now work, but its registry gates and secrets preflight still never install.
O4 stays after both for the same reason it did before: it is an end-to-end
`/project-init` run, so it verifies A18 and A19 rather than duplicating them.

**O7, unblocked.** A18 was O7's stated dependency — "the hook-delivery
mechanism has to be settled before the adapter boundary can be drawn." It is
now: hooks travel with the plugin, globally, gated by a per-repo opt-in. O7
still needs O5 (extracting the doctrine as a portable artifact) before it can
move, and stays LATER.

---

## 7 — Working agreements carried forward

Do not re-derive these; they were settled in the design conversation.

1. **Every guard gets a red-then-green proof before it counts.** Break it, see it fail, restore. A guard that passed first run has proved nothing.
2. **Every guard needs a fail-loud case** — what happens when it cannot evaluate its input. Two real bugs were found this way (`jq` absence, `git diff HEAD` on untracked files).
3. **Document a rule immediately; track its enforcement status separately.** `PROSE` on a mechanisable rule is debt with a ticket, never a silent gap.
4. **Never promote a JUDGMENT rule.** False positives → check disabled → protects nothing.
5. **Evidence over recollection.** Run `session_report.py` before concluding a rule was ignored — it may never have loaded.
6. **The registry must stay honest.** Any row claiming HOOK/TEST/GATE must have that check actually wired. `/project-audit` verifies this.
7. **Local customizations survive upgrades.** Never resolve a CONFLICT by taking the framework wholesale.
8. **Rules budget ~400 lines per repo.** Pruning is as important as adding.
