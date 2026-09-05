# Kit as a Dependency Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make dev-kit an installable dependency so every design and registry gate runs from `node_modules/@roofadvisor/dev-kit` on every machine and runner, fails (never skips) when absent, and ship the four token-builder bugs and the verified single-file seed that the scaffolded gate depends on — as dev-kit 2.2.0.

**Architecture:** `package.json` becomes `@roofadvisor/dev-kit` with `files: ["kit", "scripts", ".claude-plugin"]`; consumers pin `github:roofadvisor/dev-kit#vX.Y.Z` and `npm ci` delivers the kit to a fixed path. Release tags make the pin possible. The token builder's coverage check claims colour tiers by file, both resolvers resolve refs by real path only, and a generated seed proves single-file mode at parity. `project-init` scaffolds a project's own authoring gate; `gates.yml` runs the registry gates from `node_modules` and fails while vendored copies remain. roof-club migrates first, pinned to the branch SHA until `v2.2.0` exists.

**Tech Stack:** Node ESM (`build_tokens.mjs`, the new seed generator), Python 3 validators (`validate_tokens.py`, `check_*.py`), Bash red-then-green harnesses under `tests/` driven by `scripts/verify.sh`, GitHub Actions, npm git-ref installs, roof-club (Next.js, Vitest).

**Spec:** `docs/superpowers/specs/2026-09-04-kit-as-a-dependency-design.md` (committed `2c0600b`, on `main`)

## Global Constraints

- Every task ends green on `bash scripts/verify.sh` in this repo (roof-club tasks: `npm run verify` there). A `SKIPPED` gate is never a passed gate.
- Harnesses are red-then-green: the test is written, run, and **seen to fail** before the fix; the last line is `echo "pass=$pass fail=$fail"` and `scripts/verify.sh`'s loop reads it.
- The plugin's own CI must list every harness `scripts/verify.sh` lists — both `.github/workflows/gates.yml` ("harnesses" job, runs on pull requests) and `.github/workflows/main-verify.yml` ("Harnesses" step, runs on every push to `main`). They ran seven and six of eleven when this plan was written; `tests/release_test.sh` asserts all three lists are equal from Task 1 on.
- Conventional commits ending `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Stage explicit paths, never `git add -A`.
- `grep` on this machine is ugrep: `$`, `|`, `+`, `?`, `()` mid-pattern are regex. Use `grep -F` for every literal needle.
- The package: name `@roofadvisor/dev-kit`, `private: true`, `files` exactly `["kit", "scripts", ".claude-plugin"]`, `version` equal to `.claude-plugin/plugin.json`'s. The plugin name `dev-kit` (plugin.json, marketplace.json) does not change.
- The fixed kit path in a consumer: `node_modules/@roofadvisor/dev-kit/kit`. Presence means `scripts/build_tokens.mjs` exists there, not that the directory does. `KIT=<dir>` overrides it, for tests and plugin checkouts.
- Pin form: `"@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#v2.2.0"`; before the tag exists (Task 6), the branch SHA.
- roof-club: never edit its shared `main` checkout — work in `.worktrees/<feature>` from `origin/main`, one PR, pull the review with `npm run pr:review -- <n>` before merging (its CLAUDE.md). Its `MIN_KIT="2.1.0"` check stays.
- Versions start at 2.1.1 (both files agree since the 2.1.1 release). Release: 2.2.0, minor. Tag after merge, on the release commit, never before.
- Task order is spec §8 and is not reorderable: Task 2 reveals Task 3's typo; Task 4's seed needs Tasks 2–3; Task 6 needs Task 5's push; Task 10 needs Task 9's workflow to have run.

---

## File Structure

**This repo (dev-kit)**

| File | Responsibility | Task |
|---|---|---|
| `package.json`, `package-lock.json` | the installable package: name, `files`, version parity | 1 |
| `tests/release_test.sh` (new) | release hygiene: versions agree, name, `files`, private, CI runs every harness | 1 |
| `scripts/verify.sh:30` | the harness loop gains the tokens `release` and `relocation` (it runs `tests/${t}_test.sh`) | 1, 7 |
| `.github/workflows/gates.yml` ("harnesses" job), `.github/workflows/main-verify.yml` ("Harnesses" step) | both CI loops mirror `verify.sh`'s | 1, 7 |
| `kit/scripts/build_tokens.mjs` | B1 (colour claims by file), B2 (`spacing.semantic`), B3b (`res()` real-path only) | 2, 3 |
| `kit/scripts/validate_tokens.py` | B3b (no first-segment or `endswith` fallback) | 3 |
| `kit/tokens/data-viz.json:37-38` | B3 (`{dataviz.…}` → `{data-viz.…}`) | 3 |
| `tests/token_build_test.sh` | regression tests for B1, B2, B3b, B3, and the seed parity | 2, 3, 4 |
| `kit/scripts/make_single_file_tokens.mjs` (new) | generates the seed; `--check` proves it current and at parity | 4 |
| `templates/scaffold/design-tokens.json` (new, generated) | the single-file seed `project-init` copies | 4 |
| `kit/scripts/accuracy_report.mjs:27` | `/gate` proves the seed on every plugin change | 4 |
| `skills/ship-it/SKILL.md` §6 | the version-parity check and the tag command | 5 |
| `templates/github/gates.yml:1-72` | header, `npm ci`, gates from `node_modules`, vendored-copy assertion | 7 |
| `skills/framework-upgrade/SKILL.md` | named migration *kit as a devDependency (2.2.0)* | 7 |
| `tests/relocation_test.sh` (new) | registry gates run from `node_modules` in a synthetic consumer | 7 |
| `skills/project-init/SKILL.md` (3.7a, step 9, step 10, line 267) | copy the seed, the project's own gate, the devDependency, `{{SETUP_CMDS}}`, no vendored copies | 8 |
| `skills/project-init/references/scaffold-spec.md` (124, 128–166) | the design-gate row and section; the superseded rationales | 8 |
| `docs/decisions/005-kit-as-a-dependency.md` (new) | the decision record | 8 |
| `docs/superpowers/specs/2026-09-04-kit-as-a-dependency-design.md` §4.3, §9 | roof-club's resolver is reduced, not deleted (fourteen call sites) | 8 |
| `.github/workflows/consumer.yml` (new) | a bare runner installs the kit from a git ref and runs the scaffolded gate | 9 |
| `CHANGELOG.md`, `.claude-plugin/plugin.json`, `package.json` | 2.2.0 | 10 |

**roof-club** (`/Users/ian-ra/code-projects/RoofAdvisor/roof-club`, worktree `.worktrees/kit-as-dependency`)

| File | Responsibility | Task |
|---|---|---|
| `package.json`, `package-lock.json` | the devDependency; `design:lint` unchanged (still via `devkit-path.sh`) | 6, 10 |
| `scripts/devkit-path.sh` | reduced to the fixed path — fourteen call sites keep working | 6 |
| `design/systems/verify.sh` | the cache-search fallback deleted; the absence message names `npm ci`; the upgrade message names the pin | 6 |
| `tests/design-verify.test.ts` | the upgrade-message assertion follows the message | 6 |
| `docs/specs/2026-08-31-design-system-family.md:301-307` | the authoring-gate paragraph says where the kit comes from | 6 |

---

### Task 1: The package, versions that must agree, and a CI that runs every harness (spec §4.1, F)

**Files:**
- Modify: `package.json` (whole file)
- Regenerate: `package-lock.json`
- Create: `tests/release_test.sh`
- Modify: `scripts/verify.sh:30`
- Modify: `.github/workflows/gates.yml` — the "Run all six harnesses" step in the `harnesses` job
- Modify: `.github/workflows/main-verify.yml` — the "Harnesses" step's loop

**Interfaces:**
- Produces: `tests/release_test.sh` — exit 0 iff `package.json.version == plugin.json.version`, `name == @roofadvisor/dev-kit`, `files == [kit, scripts, .claude-plugin]`, `private == true`, lock root name matches, and both CI harness lists (`gates.yml`, `main-verify.yml`) equal `verify.sh`'s. Task 5 tells `ship-it` to run it; Task 10 relies on it.
- Produces: `files` shipping `scripts/` — Task 7's `gates.yml` assumes `node_modules/@roofadvisor/dev-kit/scripts/check_*.py` exists in a consumer.

- [ ] **Step 1: Write the failing harness**

Create `tests/release_test.sh`:

```bash
#!/usr/bin/env bash
# Release hygiene: the two version fields must agree, and the package must ship exactly what a
# consumer's gates need — kit/ and scripts/ to run, .claude-plugin/ for the one version-read path
# (`$KIT/../.claude-plugin/plugin.json`) — and nothing else. plugin.json said 2.1.0 while
# package.json said 2.0.0 for a whole release and nothing noticed (spec §3). And the plugin's own
# CI must run every harness verify.sh runs: it ran seven of eleven, and a harness that is green
# locally and absent in CI is the shape of failure this whole release is about.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (expected '$2', got '$3')"; fi }
# One reader for every field: a list prints comma-joined, a bool prints True/False, a missing key prints None.
field() { python3 -c 'import json,sys; v=json.load(open(sys.argv[1])).get(sys.argv[2]); print(",".join(v) if isinstance(v,list) else v)' "$1" "$2"; }

check "package.json version equals plugin.json version"   "$(field "$KIT/.claude-plugin/plugin.json" version)" "$(field "$KIT/package.json" version)"
check "package name is @roofadvisor/dev-kit"              "@roofadvisor/dev-kit"        "$(field "$KIT/package.json" name)"
check "files is exactly kit, scripts, .claude-plugin"     "kit,scripts,.claude-plugin"  "$(field "$KIT/package.json" files)"
check "package stays private (no accidental npm publish)" "True"                        "$(field "$KIT/package.json" private)"
check "package-lock root name matches"                    "@roofadvisor/dev-kit"        "$(field "$KIT/package-lock.json" name)"

# The two harness lists, verbatim from their `for t in …; do` lines.
vlist=$(grep -oE '^for t in [a-z_ ]+; do' "$KIT/scripts/verify.sh" | sed -E 's/^for t in (.*); do/\1/')
clist=$(grep -oE 'for t in [a-z_ ]+; do' "$KIT/.github/workflows/gates.yml" | sed -E 's/for t in (.*); do/\1/')
check "the plugin's CI runs every harness verify.sh runs" "$vlist" "$clist"
# main-verify runs on every push to main — the surface that matters most in a repo that merges by
# fast-forward. It carried a third, six-harness list of its own.
mlist=$(grep -oE 'for t in [a-z_ ]+; do' "$KIT/.github/workflows/main-verify.yml" | sed -E 's/for t in (.*); do/\1/')
check "main-verify runs every harness verify.sh runs"      "$vlist" "$mlist"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
```

Then `chmod +x tests/release_test.sh`.

- [ ] **Step 2: Run it — expect red**

Run: `bash tests/release_test.sh`
Expected: five FAIL lines — name `dev-kit`, files `None`, lock name `dev-kit`, and the two CI lists (seven and six harnesses vs eleven) — ending `pass=2 fail=5`. The version check passes: both files say 2.1.1 since the 2.1.1 release.

- [ ] **Step 3: Rewrite `package.json`**

Replace the whole file with:

```json
{
  "name": "@roofadvisor/dev-kit",
  "version": "2.1.1",
  "private": true,
  "description": "dev-kit's kit/ and scripts/, installable as a pinned devDependency (github:roofadvisor/dev-kit#vX.Y.Z) so a project's gates run from node_modules on every machine and runner — docs/decisions/005-kit-as-a-dependency.md. Playwright is for the plugin's own render gates (measure_render, verify_states, axe_audit, verify_focustrap, verify_rtl, ...); consumers do not inherit it. See README.md Notes.",
  "files": ["kit", "scripts", ".claude-plugin"],
  "devDependencies": {
    "playwright": "^1.62.1"
  }
}
```

`2.1.1` matches `plugin.json` today; Task 10 bumps both to 2.2.0. `private: true` blocks `npm publish` and does not block git installs (measured, spec §3).

- [ ] **Step 4: Regenerate the lock's root entry**

Run: `npm install --package-lock-only --no-audit --no-fund`
Expected: `package-lock.json` changes only in its root `name`; `git diff --stat package-lock.json` shows a handful of lines.

- [ ] **Step 5: Both harness loops list the same harnesses**

In `scripts/verify.sh` line 30, change

```bash
for t in hooks render_registry render_instructions gate_trio statelessness conformance companions scanner_agreement agent_presence notion_sync token_build; do
```

to

```bash
for t in hooks render_registry render_instructions gate_trio statelessness conformance companions scanner_agreement agent_presence notion_sync token_build release; do
```

In `.github/workflows/gates.yml`, in the `harnesses` job, replace

```yaml
      - name: Run all six harnesses
        run: |
          fail=0
          for t in hooks render_registry render_instructions gate_trio statelessness conformance companions; do
```

with

```yaml
      - name: Run every harness (this list must equal scripts/verify.sh's — release_test asserts it)
        run: |
          fail=0
          for t in hooks render_registry render_instructions gate_trio statelessness conformance companions scanner_agreement agent_presence notion_sync token_build release; do
```

In `.github/workflows/main-verify.yml`, in the `Harnesses` step, replace

```yaml
          for t in hooks render_registry gate_trio statelessness conformance companions; do
```

with

```yaml
          for t in hooks render_registry render_instructions gate_trio statelessness conformance companions scanner_agreement agent_presence notion_sync token_build release; do
```

`scanner_agreement`, `agent_presence`, `notion_sync` and `token_build` had never run in CI, and `main-verify` had also dropped `render_instructions`. They pass locally without network or secrets; if one fails on the runner when Task 5 pushes, that is a real finding about a harness that only passes on a laptop — fix it, do not drop it from the list.

- [ ] **Step 6: Run it — expect green**

Run: `bash tests/release_test.sh`
Expected: `pass=7 fail=0`.

Run: `bash scripts/verify.sh 2>&1 | tail -4`
Expected: `VERIFY PASSED`, and the harness table lists `release  pass=7 fail=0`.

- [ ] **Step 7: Confirm what `files` would ship**

Run: `npm pack --dry-run 2>&1 | grep -E "unpacked size|total files|package size"`
Expected: about 1 MB unpacked, roughly 160 files; no `skills/`, `templates/`, or `tests/` entries in the listing.

- [ ] **Step 8: Commit**

```bash
git add package.json package-lock.json tests/release_test.sh scripts/verify.sh .github/workflows/gates.yml .github/workflows/main-verify.yml
git commit -m "chore: package.json is @roofadvisor/dev-kit and ships kit/ scripts/ .claude-plugin/; CI runs every harness

package.json said 2.0.0 while plugin.json said 2.1.0 for a whole release.
tests/release_test.sh fails when they disagree, and pins the name, the files
list and private:true — the fields a consumer's pinned install depends on
(spec §4.1, F). It also asserts the plugin's own CI harness loop equals
verify.sh's: CI ran seven of eleven harnesses, and four — including the
token builder's — were green locally and absent there.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: B1 + B2 — colour tiers are claimed by their file, and `spacing.semantic` emits (spec §4.7)

**Files:**
- Modify: `kit/scripts/build_tokens.mjs:120` (GROUPS) and the `claimed` / `covers` blocks (lines 255–259 and 291–294)
- Test: `tests/token_build_test.sh`

**Interfaces:**
- Consumes: `tests/token_build_test.sh`'s helpers `fixture()`, `check()`, `has()`, `hasnt()`, and `$B` = `kit/scripts/build_tokens.mjs`, `$KIT` = repo root.
- Produces: `--space-page-*`, `--space-card-*`, `--space-stack-*`, `--space-inline-*`, `--space-component-*` (30 vars); the coverage report names `<file>.semantic` for a non-colour file. Task 4's parity test counts them.

- [ ] **Step 1: Make the harness helpers literal**

In `tests/token_build_test.sh`, the two helpers use regex grep. Every needle in this file is literal, and ugrep reads `$` as an anchor, so change

```bash
has()   { if printf '%s' "$2" | grep -q -- "$3"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (missing: $3)"; fi }
hasnt() { if printf '%s' "$2" | grep -q -- "$3"; then fail=$((fail+1)); echo "FAIL: $1 (unexpected: $3)"; else pass=$((pass+1)); fi }
```

to

```bash
has()   { if printf '%s' "$2" | grep -qF -- "$3"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (missing: $3)"; fi }
hasnt() { if printf '%s' "$2" | grep -qF -- "$3"; then fail=$((fail+1)); echo "FAIL: $1 (unexpected: $3)"; else pass=$((pass+1)); fi }
```

Run `bash tests/token_build_test.sh` — still `pass=17 fail=0`.

- [ ] **Step 2: Write the failing tests**

Insert before the final `echo "pass=$pass fail=$fail"` in `tests/token_build_test.sh`:

```bash
# ---------- B1: colour tiers are claimed by their FILE, not by bare name ----------
# 2.1.0 seeded `claimed` with bare 'primitive','semantic','component','dark', so a top-level
# `semantic` in ANY file read as covered — spacing.json's 30 semantic tokens hid behind it.
D="$(fixture)"
cat > "$D/layout.json" <<'JSON'
{ "semantic": { "gutter": { "md": {"$type":"dimension","$value":"24px"} } } }
JSON
out=$(node "$B" --in "$D" --out "$D/out.css" 2>&1)
has "B1: a non-colour file's top-level semantic group is reported" "$out" "layout.semantic"
rm -rf "$D"

# ---------- B2: spacing.semantic emits ----------
css=$(node "$B" --in "$KIT/kit/tokens" 2>/dev/null)
has "B2: --space-page-inline-padding emits"        "$css" "--space-page-inline-padding:"
has "B2: --space-stack-md emits"                   "$css" "--space-stack-md:"
has "B2: --space-component-button-padding-x emits" "$css" "--space-component-button-padding-x:"
node "$B" --in "$KIT/kit/tokens" --out /dev/null --strict >/dev/null 2>&1; check "B2: the kit's own tokens are --strict clean" 0 $?
```

`layout` is not a `GROUPS` path and not in `NOT_EMITTED`, so its `semantic` can only be covered by the bare-tier accident.

- [ ] **Step 3: Run — expect red**

Run: `bash tests/token_build_test.sh`
Expected: `FAIL: B1 …` (nothing reported — the bare claim hides it) and three `FAIL: B2 …` (no `--space-page-*` vars), `pass=18 fail=4` — the 17 existing checks plus the passing `--strict clean` one. The `--strict clean` check passes for now — the tokens are hidden, not reported.

- [ ] **Step 4: B1 — claim colour tiers by file**

In `kit/scripts/build_tokens.mjs`, replace

```js
const claimed = ['primitive', 'semantic', 'component', 'dark']; // colours: handled in step 3
for (const [paths, prefix] of GROUPS) {
```

with

```js
// Colour tiers are claimed by the FILE that carries them — `colors` in a directory, the file
// itself in single-file mode — and matched on a leaf's full path only (below). 2.1.0 claimed
// them bare, so a top-level `semantic` in any file read as covered: spacing.json's 30 semantic
// tokens were hidden from the report that way (2.2.0, B1).
const colourStem = (SINGLE ? SOURCES[0] : 'colors.json').replace(/\.json$/, '');
const colourClaims = ['primitive', 'semantic', 'component', 'dark'].map(t => `${colourStem}.${t}`);
const claimed = [];
for (const [paths, prefix] of GROUPS) {
```

and replace

```js
const covers = (path) => claimed.some(c => path === c || path.startsWith(`${c}.`));
const excused = (path) => NOT_EMITTED.some(([c]) => path === c || path.startsWith(`${c}.`));
const unmapped = leaves.filter(
  (l) => !covers(l.bare) && !covers(l.full) && !excused(l.bare) && !excused(l.full)
);
```

with

```js
const covers = (path) => claimed.some(c => path === c || path.startsWith(`${c}.`));
const colourCovered = (full) => colourClaims.some(c => full === c || full.startsWith(`${c}.`));
const excused = (path) => NOT_EMITTED.some(([c]) => path === c || path.startsWith(`${c}.`));
const unmapped = leaves.filter(
  (l) => !covers(l.bare) && !covers(l.full) && !colourCovered(l.full) && !excused(l.bare) && !excused(l.full)
);
```

- [ ] **Step 5: Run — B1 green, and the kit now reports its own 30**

Run: `bash tests/token_build_test.sh`
Expected: B1 passes; `B2: the kit's own tokens are --strict clean` now FAILS (30 `spacing.semantic.*` tokens reported). This is the fix revealing its partner — do not commit here.

- [ ] **Step 6: B2 — map `spacing.semantic`**

In `kit/scripts/build_tokens.mjs` after line 120

```js
  [['space', 'spacing.scale'], 'space-'],
```

add

```js
  [['spacing.semantic'], 'space-'],                 // page/card/stack/inline/component — 30 tokens B1 had hidden
```

- [ ] **Step 7: Run — expect green**

Run: `bash tests/token_build_test.sh`
Expected: `pass=22 fail=0`.

Run: `node kit/scripts/build_tokens.mjs --in kit/tokens 2>/dev/null | grep -cF -- '--space-'`
Expected: 21 (the 21-step scale) + 30 = `51`.

Run: `bash scripts/verify.sh 2>&1 | tail -3` → `VERIFY PASSED`.

- [ ] **Step 8: Commit**

```bash
git add kit/scripts/build_tokens.mjs tests/token_build_test.sh
git commit -m "fix: build_tokens claims colour tiers by file, and spacing.semantic emits (B1, B2)

2.1.0's coverage report claimed primitive/semantic/component/dark by bare
name, so any file's top-level \`semantic\` read as covered. spacing.json's
30 semantic tokens hid behind it — the report that exists to stop tokens
vanishing in silence had a blind spot the same shape. Colour tiers are now
claimed as <file>.<tier> and matched on a leaf's full path; spacing.semantic
gets its GROUPS entry and emits --space-page-*, --space-stack-*,
--space-component-*. One commit because the first fix reveals the second.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: B3b + B3 — a ref resolves by its real path, and the `data-viz` typo (spec §4.7)

**Files:**
- Modify: `kit/scripts/build_tokens.mjs` (`res()`, lines 66–69)
- Modify: `kit/scripts/validate_tokens.py:104-110`
- Modify: `kit/tokens/data-viz.json:37-38`
- Test: `tests/token_build_test.sh`

**Interfaces:**
- Produces: both resolvers accept `{a.rest}` only when it is a key in the token map (which already holds every leaf bare and stem-namespaced). Task 4's seed generator relies on this — every ref it writes is a real path.

- [ ] **Step 1: Write the failing tests**

Insert before the final `echo "pass=$pass fail=$fail"`:

```bash
# ---------- B3b: a ref resolves by its real path, never by dropping a first segment ----------
# `{nope.primitive.ink.900}` used to resolve: both resolvers stripped any first segment and
# retried — leaving `primitive.ink.900`, a real key — and validate_tokens then matched any key
# ENDING in the ref. That is how `{dataviz.…}` passed for a file called data-viz.json. The fake
# ref needs one segment MORE than the real path: `{nope.ink.900}` would strip to `ink.900`, which
# is not a key, and the test would pass before the fix for the wrong reason.
D="$(fixture)"
python3 - "$D/colors.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["semantic"]["text"]["primary"]["$value"] = "{nope.primitive.ink.900}"
json.dump(d, open(p, "w"))
PY
python3 "$KIT/kit/scripts/validate_tokens.py" "$D" >/dev/null 2>&1; check "B3b: validate_tokens rejects a ref through a namespace that is not a file" 1 $?
css=$(node "$B" --in "$D" 2>/dev/null)
hasnt "B3b: the builder does not emit a value reached through a fake namespace" "$css" "--color-text-primary:"
rm -rf "$D"

# ---------- B3: the typo the rule now rejects, fixed at the source ----------
python3 "$KIT/kit/scripts/validate_tokens.py" "$KIT/kit/tokens" >/dev/null 2>&1; check "B3: the kit's own tokens resolve" 0 $?
css=$(node "$B" --in "$KIT/kit/tokens" 2>/dev/null)
has "B3: --color-chart-positive emits from the corrected ref" "$css" "--color-chart-positive:"
```

- [ ] **Step 2: Run — expect red**

Run: `bash tests/token_build_test.sh`
Expected: `FAIL: B3b: validate_tokens …` (exit 0 — the accident strips `nope.` and finds `primitive.ink.900`) and `FAIL: B3b: the builder …` (`--color-text-primary: #111111` is emitted through `nope.`), `pass=24 fail=2` — the 22 existing checks plus the two B3 checks, which pass for now. The B3 checks pass for now — the typo still resolves by accident.

- [ ] **Step 3: B3b in the builder**

In `kit/scripts/build_tokens.mjs`'s `res()`, replace

```js
  if (val === undefined) val = all[ref];
  if (val === undefined) { const tail = ref.split('.').slice(1).join('.'); val = all[ref] ?? all[tail]; }
  return val === undefined ? v : res(val, depth + 1, dark);
```

with

```js
  // A ref resolves by its real path only. `all` already holds every leaf both bare and
  // stem-namespaced, so `{colors.semantic.x}` and `{semantic.x}` both hit directly. The old
  // fallback dropped ANY first segment and retried, which let `{dataviz.…}` resolve for a file
  // called data-viz.json — and would let `{anything.x}` resolve for `x` (2.2.0, B3b).
  if (val === undefined) val = all[ref];
  return val === undefined ? v : res(val, depth + 1, dark);
```

- [ ] **Step 4: B3b in the validator**

In `kit/scripts/validate_tokens.py`, replace

```python
                if ref in all_tokens or norm in all_tokens:
                    continue
                # tolerate cross-file refs that omit the file prefix
                tail = norm.split(".", 1)[-1]
                if tail in all_tokens:
                    continue
                if any(k.endswith(norm) for k in all_tokens):
                    continue
                unresolved.append(f"{f.name}: {path} → {{{ref}}} (unresolved)")
```

with

```python
                if ref in all_tokens or norm in all_tokens:
                    continue
                # A ref resolves by its real path only. all_tokens already holds every leaf
                # both bare and stem-namespaced, so a cross-file ref works with or without its
                # file prefix. The old fallbacks dropped any first segment, then matched any
                # key ENDING in the ref — which is how {dataviz.…} passed for data-viz.json
                # (2.2.0, B3b).
                unresolved.append(f"{f.name}: {path} → {{{ref}}} (unresolved)")
```

- [ ] **Step 5: Run — B3b green, B3 now red**

Run: `bash tests/token_build_test.sh`
Expected: both B3b checks pass; `B3: the kit's own tokens resolve` FAILS (`data-viz.json: semantic.positive → {dataviz.diverging.positive-strong} (unresolved)` and `negative-strong`) and `--color-chart-positive` is absent. The rule revealing the typo — do not commit here.

- [ ] **Step 6: B3 — fix the typo**

In `kit/tokens/data-viz.json` lines 37–38, change `{dataviz.diverging.positive-strong}` to `{data-viz.diverging.positive-strong}` and `{dataviz.diverging.negative-strong}` to `{data-viz.diverging.negative-strong}`.

- [ ] **Step 7: Run — expect green**

Run: `bash tests/token_build_test.sh` → `pass=26 fail=0`.
Run: `bash scripts/verify.sh 2>&1 | tail -3` → `VERIFY PASSED`.

- [ ] **Step 8: Commit**

```bash
git add kit/scripts/build_tokens.mjs kit/scripts/validate_tokens.py kit/tokens/data-viz.json tests/token_build_test.sh
git commit -m "fix: token refs resolve by their real path, never by dropping a first segment (B3b, B3)

Both resolvers stripped any first segment and retried, and the validator
then matched any key ending in the ref. {nope.primitive.ink.900} resolved. So did
data-viz.json's {dataviz.…} — a typo that had never been seen because the
accident absorbed it. A ref now has to be a key; the map already carries
every leaf bare and stem-namespaced, so every legitimate form still hits.
The typo is fixed at the source in the same commit, because the rule is
what makes it visible.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: The single-file seed, generated and proven at parity (spec §4.4a)

**Files:**
- Create: `kit/scripts/make_single_file_tokens.mjs`
- Create: `templates/scaffold/design-tokens.json` (generated — never hand-edited)
- Modify: `kit/scripts/accuracy_report.mjs:27` (three `checks` entries)
- Test: `tests/token_build_test.sh`

**Interfaces:**
- Produces: `node kit/scripts/make_single_file_tokens.mjs` writes the seed; `--check` exits 0 iff the committed seed equals a fresh generation AND its `--strict` build emits the same sorted lines as `kit/tokens/`; exit 2 otherwise. `--out <path>` overrides the destination. Task 8's 3.7a copies the seed; Task 9's job runs the scaffolded gate on it.

- [ ] **Step 1: Write the failing test**

Insert before the final `echo "pass=$pass fail=$fail"`:

```bash
# ---------- the single-file seed builds at parity with the directory (spec §4.4a) ----------
# A scaffolded project starts from one file. A literal merge of kit/tokens/*.json builds 70 of
# 320 variables; the seed is the one shape that builds them all, and --check proves it stays so.
node "$KIT/kit/scripts/make_single_file_tokens.mjs" --check >/dev/null 2>&1; check "seed: current, --strict clean, at parity with kit/tokens" 0 $?
python3 "$KIT/kit/scripts/validate_tokens.py"   "$KIT/templates/scaffold/design-tokens.json" >/dev/null 2>&1; check "seed: every alias resolves" 0 $?
python3 "$KIT/kit/scripts/validate_contrast.py" "$KIT/templates/scaffold/design-tokens.json" >/dev/null 2>&1; check "seed: WCAG pairs pass" 0 $?
```

- [ ] **Step 2: Run — expect red**

Run: `bash tests/token_build_test.sh`
Expected: three FAILs (no generator, no seed), `pass=26 fail=3`.

- [ ] **Step 3: Write the generator**

Create `kit/scripts/make_single_file_tokens.mjs`:

```js
#!/usr/bin/env node
/**
 * Generates templates/scaffold/design-tokens.json — the single-file seed a scaffolded project
 * starts from — out of kit/tokens/*.json, and proves it with --check.
 *
 * Why generated: project-init 3.7a used to say "seeded from kit/tokens/" and leave the merge to
 * the agent. A literal merge builds 70 of 320 variables after seven silent key collisions. The
 * shape that builds at parity is specific (spec §4.4a):
 *   1. colors.json's tiers — primitive, semantic, component, dark — are hoisted to the top level,
 *      where the colour emitter reads them in single-file mode (build_tokens.mjs, step 3);
 *   2. every other file is keyed by its stem (typography, spacing, …) — exactly the directory-form
 *      paths GROUPS already reads;
 *   3. every {ref} is rewritten to a path that EXISTS in the result, chosen by existence rather
 *      than by rule order: data-viz.json and spacing.json both carry their own `semantic`, and
 *      states.json references shadows.json's `focus-ring` bare.
 *
 *   node scripts/make_single_file_tokens.mjs             # writes the seed
 *   node scripts/make_single_file_tokens.mjs --check     # exit 2 if the committed seed differs from a
 *                                                        # fresh generation, or does not build at parity
 *                                                        # with tokens/ under --strict (accuracy_report
 *                                                        # runs this on every /gate)
 */
import { readFileSync, readdirSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';

const KIT = fileURLToPath(new URL('../', import.meta.url)); // …/kit/
const TOKENS = join(KIT, 'tokens');
const argAfter = (flag) => (process.argv.includes(flag) ? process.argv[process.argv.indexOf(flag) + 1] : null);
const OUT = resolve(argAfter('--out') || join(KIT, '..', 'templates', 'scaffold', 'design-tokens.json'));
const CHECK = process.argv.includes('--check');
const TIERS = ['primitive', 'semantic', 'component', 'dark'];

const files = readdirSync(TOKENS).filter(n => n.endsWith('.json')).sort();
const data = Object.fromEntries(files.map(f => [f.replace(/\.json$/, ''), JSON.parse(readFileSync(join(TOKENS, f), 'utf8'))]));
const stems = Object.keys(data);
if (!data.colors) throw new Error('kit/tokens/colors.json is required');
for (const t of TIERS) if (stems.includes(t)) throw new Error(`kit/tokens/${t}.json would collide with the hoisted colour tier "${t}"`);

// 1–2) the shape
const seed = {
  $schema: 'https://design-tokens.github.io/community-group/format/',
  $description: 'GENERATED by kit/scripts/make_single_file_tokens.mjs from kit/tokens/*.json — do not edit. Colour tiers are top-level; every other token file is keyed by its stem. Regenerate: node kit/scripts/make_single_file_tokens.mjs. Verified on every /gate: --check.',
};
for (const t of TIERS) if (t in data.colors) seed[t] = data.colors[t];
for (const s of stems) if (s !== 'colors') seed[s] = data[s];

// every path in the result — groups and leaves — so a rewrite can be chosen by existence
const paths = new Set();
(function walk(o, p) {
  if (!o || typeof o !== 'object' || Array.isArray(o)) return;
  for (const [k, v] of Object.entries(o)) {
    if (k.startsWith('$')) continue;
    const q = p ? `${p}.${k}` : k;
    paths.add(q);
    walk(v, q);
  }
})(seed, '');

// 3) rewrite refs, by existence
function rewrite(ref, stem) {
  let r = ref.trim();
  while (r.startsWith('../') || r.startsWith('./')) r = r.startsWith('../') ? r.slice(3) : r.slice(2);
  const candidates = [
    r,                                                             // already real: a hoisted tier, or stem-qualified
    stem !== 'colors' ? `${stem}.${r}` : null,                     // intra-file: {fontSize.2xl} inside typography.json
    r.startsWith('colors.') ? r.slice('colors.'.length) : null,    // {../colors.semantic.x} → hoisted
    ...stems.filter(s => s !== stem && s !== 'colors').map(s => `${s}.${r}`), // bare into another file: {focus-ring}
  ].filter(Boolean);
  const hit = candidates.find(c => paths.has(c));
  if (!hit) throw new Error(`{${ref}} in ${stem}.json resolves to nothing in the seed`);
  return hit;
}
// Only values are rewritten — a $description that happens to contain braces is prose.
function rewriteAll(node, stem) {
  if (typeof node === 'string') return node.replace(/\{([^}]+)\}/g, (_, ref) => `{${rewrite(ref, stem)}}`);
  if (Array.isArray(node)) return node.map(n => rewriteAll(n, stem));
  if (node && typeof node === 'object') {
    return Object.fromEntries(Object.entries(node).map(([k, v]) => [k, k.startsWith('$') && k !== '$value' ? v : rewriteAll(v, stem)]));
  }
  return node;
}
for (const t of TIERS) if (t in seed) seed[t] = rewriteAll(seed[t], 'colors');
for (const s of stems) if (s !== 'colors') seed[s] = rewriteAll(seed[s], s);

const text = JSON.stringify(seed, null, 2) + '\n';

if (!CHECK) {
  writeFileSync(OUT, text);
  console.log(`wrote ${OUT} (${paths.size} paths)`);
  process.exit(0);
}

// --check: the committed seed is current, and builds at parity with the directory
let fail = 0;
let current = '';
try { current = readFileSync(OUT, 'utf8'); } catch { /* a missing seed is drift */ }
if (current !== text) {
  console.error(`DRIFT: ${OUT} differs from a fresh generation — run: node kit/scripts/make_single_file_tokens.mjs`);
  fail = 2;
}

// Every emitted line, sorted: names AND values. Order differs between layouts; nothing else may.
const build = (input) => execFileSync('node', [join(KIT, 'scripts', 'build_tokens.mjs'), '--in', input, '--strict'],
  { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).split('\n').filter(l => /^\s+--/.test(l)).map(l => l.trim()).sort();

const tmp = mkdtempSync(join(tmpdir(), 'seed-'));
try {
  writeFileSync(join(tmp, 'design-tokens.json'), text);
  const dir = build(TOKENS);
  const single = build(join(tmp, 'design-tokens.json'));
  const missing = dir.filter(l => !single.includes(l));
  const extra = single.filter(l => !dir.includes(l));
  if (missing.length || extra.length) {
    console.error(`PARITY: directory build ${dir.length} lines, single-file build ${single.length}`);
    for (const l of missing.slice(0, 10)) console.error(`  missing in single-file: ${l}`);
    for (const l of extra.slice(0, 10)) console.error(`  extra in single-file:   ${l}`);
    fail = 2;
  } else if (!fail) {
    console.log(`OK: seed is current and builds at parity (${dir.length} lines in both layouts, --strict clean)`);
  }
} catch (e) {
  console.error(`PARITY: a build failed — ${(e.stderr || e.message || '').toString().trim()}`);
  fail = 2;
} finally {
  rmSync(tmp, { recursive: true, force: true });
}
process.exit(fail);
```

- [ ] **Step 4: Generate the seed, and look at what the rewrite did**

Run: `node kit/scripts/make_single_file_tokens.mjs`
Expected: `wrote …/templates/scaffold/design-tokens.json (N paths)`.

Run: `python3 -c "import json;d=json.load(open('templates/scaffold/design-tokens.json'));print([k for k in d if not k.startswith('\$')])"`
Expected: `['primitive', 'semantic', 'component', 'dark', 'blur', 'borders', 'breakpoints', 'data-viz', 'gradients', 'motion', 'opacity', 'shadows', 'sizing', 'spacing', 'states', 'theming', 'typography']`.

Run: `grep -cF -- '{focus-ring}' templates/scaffold/design-tokens.json; grep -cF -- '{shadows.focus-ring}' templates/scaffold/design-tokens.json`
Expected: `0` then `1` — states.json's bare cross-file ref was rewritten by existence.

Run: `grep -cF -- '{typography.fontSize.' templates/scaffold/design-tokens.json`
Expected: a positive count — typography's intra-file refs are stem-qualified.

- [ ] **Step 5: Run the check and the tests — expect green**

Run: `node kit/scripts/make_single_file_tokens.mjs --check`
Expected: `OK: seed is current and builds at parity (… lines in both layouts, --strict clean)`. If it prints `PARITY:` with missing lines, the seed's shape is wrong for those tokens — the rewrite rule, not the tokens, is what to fix; do not edit the seed by hand.

Run: `bash tests/token_build_test.sh` → `pass=29 fail=0`.

- [ ] **Step 6: Make `/gate` prove it on every plugin change**

In `kit/scripts/accuracy_report.mjs`, after line 27

```js
  ['Token JSON valid + aliases resolve', 'python3 scripts/validate_tokens.py tokens'],
```

add

```js
  // The single-file seed a scaffolded project starts from: current, and at parity with tokens/.
  // Commands run with cwd = kit/, so the seed is ../templates/scaffold/…
  ['Single-file seed is current and builds at parity with tokens/', 'node scripts/make_single_file_tokens.mjs --check'],
  ['Single-file seed — aliases resolve', 'python3 scripts/validate_tokens.py ../templates/scaffold/design-tokens.json'],
  ['Single-file seed — WCAG contrast', 'python3 scripts/validate_contrast.py ../templates/scaffold/design-tokens.json'],
```

Run: `node kit/scripts/accuracy_report.mjs 2>&1 | grep -F "Single-file seed"`
Expected: three PASS lines.

- [ ] **Step 7: Prove the drift detection fires**

Run:
```bash
cp templates/scaffold/design-tokens.json /tmp/seed.bak
python3 - <<'PY'
import json
p = 'templates/scaffold/design-tokens.json'; d = json.load(open(p))
d['semantic']['surface']['page']['$value'] = '#FFFFFF'
json.dump(d, open(p, 'w'), indent=2)
PY
node kit/scripts/make_single_file_tokens.mjs --check; echo "exit=$?"
cp /tmp/seed.bak templates/scaffold/design-tokens.json
```
Expected: `DRIFT: …` and `exit=2`; then the seed is restored and `--check` is green again.

Run: `bash scripts/verify.sh 2>&1 | tail -3` → `VERIFY PASSED`.

- [ ] **Step 8: Commit**

```bash
git add kit/scripts/make_single_file_tokens.mjs templates/scaffold/design-tokens.json kit/scripts/accuracy_report.mjs tests/token_build_test.sh
git commit -m "feat: a verified single-file token seed, generated from kit/tokens and proven at parity

project-init 3.7a told the agent to seed design-tokens.json from
kit/tokens/. No seed existed, and a literal merge builds 70 of 320
variables after seven silent key collisions. The seed is now generated:
colour tiers hoisted (the colour emitter reads them top-level in
single-file mode), every other file keyed by its stem, every ref rewritten
to a path that exists — chosen by existence, because data-viz.json and
spacing.json carry their own \`semantic\` and states.json references
shadows' focus-ring bare. --check regenerates and diffs, then builds both
layouts under --strict and compares every emitted line; accuracy_report
runs it, so the seed cannot drift from the tokens without /gate saying so.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Release tags, and `ship-it` cuts the next one (spec §4.2)

**Files:**
- Tags: `v2.0.0` → `57fc95f`, `v2.0.1` → `9c52b0d`, `v2.1.0` → `e7aa5f8`, `v2.1.1` → `121620f` (all on `origin/main`)
- Modify: `skills/ship-it/SKILL.md` §6

**Interfaces:**
- Produces: `git describe --tags --abbrev=0` works (`ship-it` §6 already calls it); a pushed branch whose HEAD SHA Task 6 pins.

- [ ] **Step 1: Confirm the targets, then tag**

Run: `for c in 57fc95f 9c52b0d e7aa5f8 121620f; do git merge-base --is-ancestor $c origin/main && git log -1 --format='%h %s' $c; done`
Expected: four lines — `feat: merge f4d-kit tree into dev-kit 2.0.0`, `release: 2.0.1 — …`, `release: 2.1.0 — …`, `release: 2.1.1 — …`.

Run:
```bash
git tag -a v2.0.0 -m "release: 2.0.0 — dev-kit: design-kit and f4d-kit merged into one plugin" 57fc95f
git tag -a v2.0.1 -m "release: 2.0.1 — the guards stop firing on ordinary work" 9c52b0d
git tag -a v2.1.0 -m "release: 2.1.0 — the token builder stops discarding your tokens" e7aa5f8
git tag -a v2.1.1 -m "release: 2.1.1 — Rule 0 allows a plan beside its spec" 121620f
git push origin v2.0.0 v2.0.1 v2.1.0 v2.1.1
git describe --tags --abbrev=0
```
Expected: the push reports four new tags; `describe` prints `v2.1.1`.

- [ ] **Step 2: Teach `ship-it` the version check and the tag command**

In `skills/ship-it/SKILL.md` §6, replace

```markdown
- Add a `CHANGELOG.md` entry written for a consumer, not a committer.
- Tag after merge, never before, and only on explicit confirmation.
```

with

```markdown
- Add a `CHANGELOG.md` entry written for a consumer, not a committer.
- Bump `version` in **both** `.claude-plugin/plugin.json` and `package.json`, then run
  `bash tests/release_test.sh` — it fails if they disagree. The plugin updater compares
  version strings, not commits, and consumers pin the tag below; a release with only one
  field bumped reaches neither.
- Tag after merge, never before, and only on explicit confirmation — on the release
  commit once it is on `main`:
  `git tag -a v<X.Y.Z> -m "release: <X.Y.Z> — <title>" <release commit> && git push origin v<X.Y.Z>`.
  A consumer's `"@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#v<X.Y.Z>"` resolves only
  after this push.
```

- [ ] **Step 3: Verify, commit, and push the branch**

Run: `bash scripts/verify.sh 2>&1 | tail -3` → `VERIFY PASSED`.

```bash
git add skills/ship-it/SKILL.md
git commit -m "docs: ship-it checks version parity and tags the release; v2.0.0–v2.1.1 backfilled

There were no tags. ship-it §6 already listed commits since the last one,
which failed; consumers had only a SHA to pin. Annotated tags now sit on
the commits that set each version, and §6 says how the next one is cut —
on the release commit, after merge, after release_test passes.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push -u origin HEAD
git rev-parse HEAD
```

Record the printed SHA: it is Task 6's interim pin. A git-ref install fetches it only because the branch is on GitHub. Then trigger the plugin's own CI: its `harnesses` and `gates` jobs run on pull requests only (`on: pull_request`), and this branch lands on `main` by fast-forward, so open a draft PR — `gh pr create --draft --base main --head "$(git rev-parse --abbrev-ref HEAD)" --title "2.2.0 — the kit is a dependency" --body "Draft, to run CI on the branch; it merges by fast-forward at Task 10. 🤖 Generated with [Claude Code](https://claude.com/claude-code)"` — then `sleep 120; gh run list --branch "$(git rev-parse --abbrev-ref HEAD)" --limit 3 --json workflowName,conclusion`. The `harnesses` job now runs twelve harnesses on a runner for the first time; a failure there is a harness that only passes on a laptop, and it is fixed before Task 6 pins this SHA.

---

### Task 6: roof-club migrates — pinned to the branch SHA (spec §4.3, §4.4d, §5)

**Files** (roof-club worktree `.worktrees/kit-as-dependency`, branch `feat/kit-as-dependency`):
- Modify: `package.json` (devDependencies)
- Regenerate: `package-lock.json`
- Rewrite: `scripts/devkit-path.sh`
- Modify: `design/systems/verify.sh:114-147` (delete), `:149-163` (message), `:181` (upgrade line)
- Modify: `tests/design-verify.test.ts:43`
- Modify: `docs/specs/2026-08-31-design-system-family.md:301-307`

**Interfaces:**
- Consumes: `SHA` from Task 5.
- Produces: roof-club's `npm run verify` green with no plugin cache reachable; an open PR that Task 10 re-pins to `v2.2.0` and merges.

**Why the resolver is reduced, not deleted.** Spec §4.3 says delete `scripts/devkit-path.sh`. It has fourteen call sites, not three: `design/systems/verify.sh:117`, `package.json`'s `design:lint`, `design/prototype/screens/DESIGN-BRIEF.md:155`, and ten render-gate commands in `docs/plans/2026-09-02-prototype-completion.md`. The principle — *gate commands stop resolving* — is kept by making the script print the fixed path and nothing else; the fourteen callers keep working unchanged. Task 8 amends the spec to say so.

- [ ] **Step 1: The worktree**

```bash
cd /Users/ian-ra/code-projects/RoofAdvisor/roof-club
git fetch origin
git worktree add .worktrees/kit-as-dependency -b feat/kit-as-dependency origin/main
cd .worktrees/kit-as-dependency
npm ci
```

- [ ] **Step 2: Write the failing test change first**

In `tests/design-verify.test.ts` line 43, the 2.0.1 refusal asserts the upgrade instruction. It will change from a plugin command to the pin. Replace

```ts
    expect(out).toMatch(/claude plugin update/);
```

with

```ts
    expect(out).toMatch(/github:roofadvisor\/dev-kit#v/);   // the upgrade is a pin, not a plugin command
```

Run: `npx vitest run tests/design-verify.test.ts` → 1 failed (the message still says `claude plugin update`).

- [ ] **Step 3: Reduce `scripts/devkit-path.sh` to the fixed path**

Replace the whole file with:

```bash
#!/usr/bin/env bash
# Prints the kit/ directory the gates run from. Since dev-kit 2.2.0 the kit is a devDependency
# (`@roofadvisor/dev-kit`, pinned to a release tag in package.json), so there is nothing to
# resolve: `npm ci` puts it at one fixed path on every machine and every runner. This script
# exists only because fourteen commands — verify.sh, design:lint, the design brief, and the
# prototype-completion plan's render gates — call it; none of them needs to change.
# KIT=<dir> overrides it, for the tests and for a checkout of the plugin itself.
set -u
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
kit="${KIT:-$root/node_modules/@roofadvisor/dev-kit/kit}"
if [ ! -f "$kit/scripts/build_tokens.mjs" ]; then
  echo "dev-kit is not installed — the gates run from node_modules/@roofadvisor/dev-kit. Run: npm ci" >&2
  exit 1
fi
printf '%s\n' "$kit"
```

- [ ] **Step 4: `design/systems/verify.sh` — delete the search, fix the two messages**

Delete lines 114–147 — from

```bash
if [ -z "${KIT:-}" ]; then
  # Ask the registry-backed resolver first — the same one every render-gate command uses —
```

through

```bash
  [ -n "$best_root" ] && KIT="$best_root/roofadvisor/$best_name/$best_version/kit"
fi
```

inclusive — and put in their place:

```bash
# The kit is a devDependency (dev-kit ADR 005): `npm ci` puts it at a fixed path, so nothing here
# resolves anything. devkit-path.sh prints that path (or fails naming npm ci); KIT overrides it.
if [ -z "${KIT:-}" ]; then
  KIT="$("$HERE/../../scripts/devkit-path.sh" 2>/dev/null || true)"
fi
```

In the `MSG` heredoc that follows, replace

```
ERROR: the roofadvisor/dev-kit plugin was not found (nor its predecessor design-kit).

  Install it:
    /plugin marketplace add roofadvisor/dev-kit
    /plugin install dev-kit@roofadvisor

  Or point KIT at an existing install's kit/ directory:
    KIT=/path/to/dev-kit/kit design/systems/verify.sh
```

with

```
ERROR: dev-kit is not installed — the token gate runs from node_modules/@roofadvisor/dev-kit.

  Install it (a devDependency in package.json):
    npm ci

  Or point KIT at a checkout of the plugin's kit/ directory:
    KIT=/path/to/dev-kit/kit design/systems/verify.sh
```

And in the `MIN_KIT` refusal, replace

```
  Upgrade:  claude plugin update dev-kit@roofadvisor
```

with

```
  Upgrade:  pin a newer tag in package.json — "@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#vX.Y.Z" — then npm install
```

The `version_ge` function above these lines stays: `MIN_KIT` still uses it.

- [ ] **Step 5: The devDependency, at the interim pin**

With `SHA` from Task 5, in `package.json` after the line `"devDependencies": {` add, as the first entry:

```json
    "@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#SHA",
```

(the literal 40-character SHA in place of `SHA`). Then:

```bash
npm install --no-audit --no-fund
test -f node_modules/@roofadvisor/dev-kit/kit/scripts/build_tokens.mjs && echo "kit present"
test -f node_modules/@roofadvisor/dev-kit/.claude-plugin/plugin.json && echo "manifest present"
! test -e node_modules/@roofadvisor/dev-kit/skills && echo "files scoped: no skills/"
grep -F '"node_modules/@roofadvisor/dev-kit"' package-lock.json | head -1
```
Expected: all three echoes; the lock line shows `"resolved": "git+ssh://git@github.com/roofadvisor/dev-kit.git#<SHA>"`. `design:lint` in `scripts` does not change — it still calls `devkit-path.sh`.

- [ ] **Step 6: The spec paragraph**

In `docs/specs/2026-08-31-design-system-family.md`, replace

```
**The authoring gate** `[wired 2026-09-04]` — `design/systems/verify.sh`: validity, contrast,
coherence, and, with dev-kit ≥ 2.1.0, unmapped token groups made fatal by `--strict` — runs on
every `npm run verify` as `design:verify`, for all three systems. It is the per-system gate §9
commits to. It needs the plugin, so it **fails, never skips,** when the plugin is absent or older
than 2.1.0: a builder that ignores `--strict` without a word would report green while checking
less than it claims.
```

with

```
**The authoring gate** `[wired 2026-09-04]` — `design/systems/verify.sh`: validity, contrast,
coherence, and, with dev-kit ≥ 2.1.0, unmapped token groups made fatal by `--strict` — runs on
every `npm run verify` as `design:verify`, for all three systems. It is the per-system gate §9
commits to. It runs from `node_modules/@roofadvisor/dev-kit` — the kit is a devDependency
pinned to a release tag (dev-kit ADR 005) `[dependency 2026-09-04]` — so it **fails, never
skips,** when `npm ci` has not run or the pinned kit is older than 2.1.0: a builder that ignores
`--strict` without a word would report green while checking less than it claims.
```

- [ ] **Step 7: Green — with no plugin cache reachable**

Run: `npx vitest run tests/design-verify.test.ts` → 3 passed.

Run: `env -u KIT HOME="$(mktemp -d)" CLAUDE_CONFIG_DIR=/nonexistent npm run verify 2>&1 | grep -E "Tests |KIT:|GREEN|OK:|FAIL|Compiled"`
Expected: `KIT: …/node_modules/@roofadvisor/dev-kit/kit (2.1.1)`, `ALL SYSTEMS GREEN`, the `OK:` lines, `Compiled successfully`, 213+ tests. `HOME` is masked so `~/.claude/plugins` cannot be consulted; the gate ran from `node_modules` or not at all.

Run: `npm run design:lint 2>&1 | tail -1` → `OK: no hardcoded values found.`

Run: `rm -rf node_modules/@roofadvisor && npm run design:verify 2>&1 | head -3; npm ci >/dev/null 2>&1`
Expected: `dev-kit is not installed … Run: npm ci` and exit 1 — fail, never skip — then the kit is reinstalled.

- [ ] **Step 8: Commit, push, open the PR, pull the review**

```bash
git add package.json package-lock.json scripts/devkit-path.sh design/systems/verify.sh tests/design-verify.test.ts docs/specs/2026-08-31-design-system-family.md
git commit -m "feat: the kit is a devDependency — gates run from node_modules, never from a plugin cache

@roofadvisor/dev-kit is pinned in package.json (to the dev-kit branch SHA
until v2.2.0 is cut; the pin moves to the tag before this merges). npm ci
puts it at node_modules/@roofadvisor/dev-kit, so verify.sh stops searching
plugin caches and devkit-path.sh prints that one path or fails naming npm
ci — kept because fourteen commands call it. Proven with HOME masked:
npm run verify is green with no plugin cache reachable, and removing the
package fails the gate rather than skipping it. dev-kit ADR 005.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push -u origin feat/kit-as-dependency
gh pr create --base main --head feat/kit-as-dependency --title "feat: the kit is a devDependency — gates run from node_modules" --body-file - <<'EOF'
The design gates ran from whichever dev-kit plugin cache the machine happened to have; CI and Render have none, so the authoring gate could only ever run by hand. dev-kit is now an installable package (ADR 005 there): `npm ci` puts it at `node_modules/@roofadvisor/dev-kit`, `verify.sh` uses that path and fails naming `npm ci` when it is absent, and `devkit-path.sh` is reduced to printing it — kept because fourteen commands across the design brief and the prototype-completion plan call it.

**Interim pin.** `package.json` pins the dev-kit branch SHA that carries the packaging; the pin moves to `github:roofadvisor/dev-kit#v2.2.0` in this PR before it merges, once that tag exists. Do not merge before that commit lands.

**Proven:** `npm run verify` green with `HOME` masked (no plugin cache reachable); removing the package fails `design:verify` rather than skipping it; `tests/design-verify.test.ts` covers both refusals.

**What does not change:** the Claude Code plugin install, `prebuild` (still plugin-free), the app. Render's `npm ci` now also fetches the public dev-kit repo — ~3 s, no GitHub billing.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
npm run pr:review -- "$(gh pr view --json number --jq .number)"
```

Fix or rebut every finding it prints; push again. The PR stays open until Task 10.

---

### Task 7: The registry gates come the same way (spec §4.6)

**Files:**
- Rewrite: `templates/github/gates.yml:1-72` (header and the `checks` job; `hooks` and `schema` jobs unchanged)
- Modify: `skills/framework-upgrade/SKILL.md` (a named migration before `## After applying`)
- Create: `tests/relocation_test.sh`
- Modify: `scripts/verify.sh:30`, `.github/workflows/gates.yml` and `.github/workflows/main-verify.yml` (all three harness loops)

**Interfaces:**
- Consumes: `files` shipping `scripts/` (Task 1).
- Produces: a `gates.yml` template that runs `python "node_modules/@roofadvisor/dev-kit/scripts/$1"` and fails while `.github/scripts/check_*.py` exists; the migration name *kit as a devDependency (2.2.0)* that Task 8's project-init text and ADR reference.

- [ ] **Step 1: Write the failing harness**

Create `tests/relocation_test.sh`:

```bash
#!/usr/bin/env bash
# The registry gates run from node_modules — proven in a synthetic consumer, not in this repo,
# where each scanner would find its own in-repo twin (it excludes itself by __file__, and the
# twin is a different path). Three things must hold (spec §3, §5): silent on a clean tree with
# no finding inside node_modules; a real violation still caught; and a forgotten
# .github/scripts/ copy caught by the assertion gates.yml carries — the scanners skip
# dot-directories, so nothing else would notice it.
set -uo pipefail
KIT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
check() { if [ "$2" -eq "$3" ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (expected exit $2, got $3)"; fi }
has()   { if printf '%s' "$2" | grep -qF -- "$3"; then pass=$((pass+1)); else fail=$((fail+1)); echo "FAIL: $1 (missing: $3)"; fi }
hasnt() { if printf '%s' "$2" | grep -qF -- "$3"; then fail=$((fail+1)); echo "FAIL: $1 (unexpected: $3)"; else pass=$((pass+1)); fi }

C="$(mktemp -d)"; ( cd "$C" && git init -q )
NM="$C/node_modules/@roofadvisor/dev-kit"; mkdir -p "$NM" "$C/.claude/rules" "$C/src"
cp -R "$KIT/scripts" "$NM/scripts"                                   # what `files` ships
printf -- '---\nid: core\nalways_apply: true\ntitle: Core\n---\n# Core\n' > "$C/.claude/rules/core.md"
printf 'export const x = 1;\n' > "$C/src/clean.ts"
run() { ( cd "$C" && python3 "node_modules/@roofadvisor/dev-kit/scripts/$1" 2>&1 ); }

for g in check_guess_lists check_statelessness check_log_hygiene; do
  out=$(run "$g.py"); code=$?
  check "$g: silent on a clean consumer" 0 "$code"
  hasnt "$g: never reports into node_modules" "$out" "node_modules"
done
( cd "$C" && python3 node_modules/@roofadvisor/dev-kit/scripts/render_instructions.py --rules-dir .claude/rules --write >/dev/null 2>&1 \
          && python3 node_modules/@roofadvisor/dev-kit/scripts/render_instructions.py --rules-dir .claude/rules --check >/dev/null 2>&1 )
check "render_instructions: relocated, takes --rules-dir, needs no _common" 0 $?

printf 'console.log("user", user.password);\n' > "$C/src/leak.ts"
out=$(run check_log_hygiene.py); code=$?
check "a planted credential log is caught from the relocated copy" 1 "$code"
has "the finding names the file" "$out" "src/leak.ts"
rm "$C/src/leak.ts"

# The assertion templates/github/gates.yml carries, verbatim.
guard() { ( cd "$C" && if ls .github/scripts/check_*.py >/dev/null 2>&1; then exit 1; else exit 0; fi ); }
guard; check "no vendored copies: the assertion passes on a clean consumer" 0 $?
mkdir -p "$C/.github/scripts" && cp "$NM/scripts/check_log_hygiene.py" "$C/.github/scripts/"
out=$(run check_log_hygiene.py); check "the scanners do NOT see .github/ — which is why the assertion exists" 0 $?
guard; check "a forgotten .github/scripts/ copy fails the assertion" 1 $?
grep -qF 'ls .github/scripts/check_*.py' "$KIT/templates/github/gates.yml"; check "gates.yml template carries the same assertion" 0 $?
grep -qF 'python "node_modules/@roofadvisor/dev-kit/scripts/$1"' "$KIT/templates/github/gates.yml"; check "gates.yml template runs the gates from node_modules" 0 $?
rm -rf "$C"

echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
```

`chmod +x tests/relocation_test.sh`.

- [ ] **Step 2: Run — expect red on the two template checks**

Run: `bash tests/relocation_test.sh`
Expected: the consumer cases pass (the scripts already relocate cleanly — spec §3); the last two FAIL (the template still runs `.github/scripts/`), `pass=12 fail=2`.

- [ ] **Step 3: Rewrite the template's header and `checks` job**

In `templates/github/gates.yml`, replace lines 1–72 — everything from `name: gates` through the `checks` job's `exit $fail` — with:

```yaml
name: gates
# Rule-registry gates. These FAIL the build — they are not advisory.
# Each job names the rule IDs it enforces so a failure is traceable to REGISTRY.md.
#
# The gate scripts run from node_modules/@roofadvisor/dev-kit/scripts — the kit is a
# devDependency pinned to a release tag (dev-kit ADR 005), so `npm ci` below is what puts
# them here, and they are never copied into this repository. A leftover copy under
# .github/scripts/ fails this job on purpose: the scanners skip dot-directories, so a
# forgotten copy would otherwise run stale while this job ran current, and nothing would
# say so.
#
# Deliberately no design job here. The design gate — validate_tokens, validate_contrast,
# build_tokens --strict, lint_hardcodes — is part of this project's own verify command
# (skills/project-init/references/scaffold-spec.md § "Verify command by stack") and runs
# for real in verify.yml from the same node_modules. The render gates (measure_render,
# axe) still need Playwright and Chromium and stay out of CI.

on:
  pull_request:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: read

jobs:
  checks:
    name: "registry gates — fixtures, contract, guess-lists, rollback, statelessness, commits, raw-sql, pure-imports"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - uses: actions/setup-node@v4
        with: { node-version: '20', cache: 'npm' }
      - name: Install the kit (a pinned devDependency)
        run: npm ci
      - name: No vendored gate copies may remain
        run: |
          if ls .github/scripts/check_*.py >/dev/null 2>&1; then
            echo "::error::.github/scripts/ still holds vendored gate copies. The kit is a dependency now — delete them (framework-upgrade: kit as a devDependency, 2.2.0)."
            exit 1
          fi
      # A7: one checkout, one python setup, all checks. Five separate jobs
      # spent more time on setup-python than on the checks themselves.
      # Each check reports its own rule IDs; the job fails if any fails.
      - name: Run all registry gates
        env:
          FIXTURE_MAX_AGE_DAYS: '90'
          # A8: written by the scaffolder from the interview answer. A gate that
          # fires wrongly gets disabled, and a disabled gate protects nothing.
          STATELESS_SINGLE_INSTANCE: ${{ vars.SINGLE_INSTANCE || '0' }}
        run: |
          fail=0
          run() {
            echo "::group::$1"
            python "node_modules/@roofadvisor/dev-kit/scripts/$1" || fail=1
            echo "::endgroup::"
          }
          BASE_REF=origin/${{ github.base_ref }} \
          PR_BODY="${{ github.event.pull_request.body }}" \
            run check_fixtures.py      # I-02 I-03 G-05
          run check_contract_pin.py    # K-02 K-03
          run check_guess_lists.py     # S-05
          BASE_REF=origin/${{ github.base_ref }} \
          PR_BODY="${{ github.event.pull_request.body }}" \
            run check_rollback.py      # O-02 O-03 D-05
          run check_statelessness.py   # ST-01..ST-07
          BASE_REF=origin/${{ github.base_ref }} \
            run check_commits.py       # C-06
          run check_raw_sql.py         # D-06
          run check_pure_imports.py    # S-07
          run check_catch_empty.py     # S-03
          run check_log_hygiene.py     # O-05
          run check_instruction_honesty.py  # C-10
          BASE_REF=origin/${{ github.base_ref }} \
          PR_BODY="${{ github.event.pull_request.body }}" \
            run check_test_count.py    # C-08
          exit $fail
```

Lines 74 onward (`hooks:` and `schema:` jobs) stay exactly as they are.

Run: `python3 -c "import yaml; yaml.safe_load(open('templates/github/gates.yml')); print('yaml ok')"` (pyyaml is installed for the conformance harness).

- [ ] **Step 4: The named migration**

In `skills/framework-upgrade/SKILL.md`, immediately before the line `## After applying`, insert:

````markdown
**Kit as a devDependency (2.2.0).** Gates used to find the plugin through Claude
Code's registry — an inline `node -e` fragment in the verify command, or a
project's own resolver script — and the registry gates were copies under
`.github/scripts/`. Both are replaced by one pinned dependency (ADR 005). In order:

1. `package.json` → `devDependencies["@roofadvisor/dev-kit"] = "github:roofadvisor/dev-kit#v<version>"`,
   the version this plugin reports in `installed_plugins.json`; then `npm ci`.
2. Every gate command that resolved the kit now uses
   `node_modules/@roofadvisor/dev-kit/kit`: replace the resolver fragment, or reduce the
   project's resolver script to printing that path (keep the script if other commands
   call it — count them before deleting).
3. Delete `.github/scripts/check_*.py` and `.github/scripts/render_instructions.py`
   (`notion_sync.py` may stay), then re-copy `templates/github/gates.yml`, which runs
   the gates from `node_modules` and fails while copies remain. Verify:
   `! ls .github/scripts/check_*.py`.
4. Confirm the CI setup step runs `npm ci` (`verify.yml`'s `{{SETUP_CMDS}}`).
5. Run the project verify. An upgrade that breaks verify is not done.

A project with no `package.json` cannot take a dependency; it keeps the registry
fragment and its honest `SKIPPED`, and this migration does not apply to it.

````

- [ ] **Step 5: Wire the harness into both loops, run green**

In `scripts/verify.sh` line 30, append ` relocation` to the loop list (after `release`). In `.github/workflows/gates.yml` and `.github/workflows/main-verify.yml`, append ` relocation` to each `for t in …` list in the same position. The loops run `tests/${t}_test.sh`, so the token for `tests/relocation_test.sh` is `relocation`, as `token_build` is for `token_build_test.sh`. `release_test` asserts the two lists still agree.

Run: `bash tests/relocation_test.sh` → `pass=14 fail=0`.
Run: `bash tests/release_test.sh` → `pass=7 fail=0`.
Run: `bash scripts/verify.sh 2>&1 | tail -3` → `VERIFY PASSED`, with `relocation  pass=14 fail=0` in the table.

- [ ] **Step 6: Commit**

```bash
git add templates/github/gates.yml skills/framework-upgrade/SKILL.md tests/relocation_test.sh scripts/verify.sh .github/workflows/gates.yml .github/workflows/main-verify.yml
git commit -m "feat: the registry gates run from node_modules — gates.yml, framework-upgrade, relocation test

Fourteen check_*.py were copied into every project's .github/scripts/ and
drifted the way the resolvers did. The gates.yml template now runs them from
node_modules/@roofadvisor/dev-kit/scripts after npm ci, and fails while
copies remain — necessary, not decoration: the scanners skip dot-directories,
so a forgotten copy is invisible to every one of them. tests/relocation_test.sh
proves the scripts relocate unchanged in a synthetic consumer: silent on a
clean tree, a planted credential log still caught, the assertion catching
what the scanners cannot. framework-upgrade names the migration.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: project-init scaffolds the project's own gate; the decision is recorded (spec §4.4b–e, §4.5)

**Files:**
- Modify: `skills/project-init/SKILL.md` — 3.7a (the ten lines from `7a. **Design artifacts**` to `resolves its \`var(--...)\` references against.`), step 9 (line 259), step 10 (line 260), the `gates.yml` bullet (line 267)
- Modify: `skills/project-init/references/scaffold-spec.md` — row 124; the section from `### Design-gate resolver fragment` (line 128) through the paragraph ending `instead of waiting for an audit to notice it.` (line 166)
- Create: `docs/decisions/005-kit-as-a-dependency.md`
- Modify: `docs/superpowers/specs/2026-09-04-kit-as-a-dependency-design.md` §4.3 and §9 (roof-club's resolver)

**Interfaces:**
- Consumes: the seed (Task 4), the migration name (Task 7), the fixed path.
- Produces: the exact gate command Task 9's job runs.

- [ ] **Step 1: 3.7a copies the seed and runs the project's own gate**

In `skills/project-init/SKILL.md`, replace the block that begins `7a. **Design artifacts** — only when a design bundle was selected:` and ends `resolves its \`var(--...)\` references against.` with:

````markdown
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
````

- [ ] **Step 2: Step 9 adds the dependency; step 10 documents `{{SETUP_CMDS}}`**

Replace line 259

```markdown
9. `verify` script in `package.json` and/or `Makefile`
```

with

```markdown
9. `verify` script in `package.json` and/or `Makefile`. For a Node project, also add
   `"@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#v<version>"` to `devDependencies` — the
   version this plugin reports in `installed_plugins.json` — and run `npm ci`: every design and
   registry gate runs from `node_modules/@roofadvisor/dev-kit` (ADR 005), and fails naming
   `npm ci` when it is absent. A project with no `package.json` keeps the registry fragment
   in the scaffold-spec and its honest `SKIPPED`.
```

In line 260, after the text

```
(fill `{{DB_NAME}}`, `{{SETUP_CMDS}}`, `{{VERIFY}}` — same token-fill pattern as `CLAUDE.md.tmpl` in step 2 — so the workflow runs the command step 9 established).
```

insert this sentence:

```
`{{SETUP_CMDS}}` is `npm ci` for a Node project (plus `npx playwright install --with-deps chromium` only when the verify command runs render gates): it is the line that puts the kit on the runner, which is what lets the design gate inside `{{VERIFY}}` run for real there rather than skip.
```

- [ ] **Step 3: No vendored copies**

Replace the bullet at line 267

```markdown
   - `.github/workflows/gates.yml`, copied from `${CLAUDE_PLUGIN_ROOT}/templates/github/gates.yml`, plus `scripts/check_*.py` copied to `.github/scripts/` — only the jobs whose rules this project holds. Also copy `scripts/render_instructions.py`, the renderer that `check_instruction_honesty.py` (C-10) depends on. Delete the rest; a gate for a rule the project does not have will fail confusingly.
```

with

```markdown
   - `.github/workflows/gates.yml`, copied from `${CLAUDE_PLUGIN_ROOT}/templates/github/gates.yml` — only the jobs whose rules this project holds; delete the rest, a gate for a rule the project does not have will fail confusingly. The gate scripts are **not** copied: the workflow runs them from `node_modules/@roofadvisor/dev-kit/scripts/` (the devDependency from step 9; ADR 005) and fails while `.github/scripts/` holds `check_*.py` copies.
```

- [ ] **Step 4: The scaffold-spec's design-gate row and section**

Replace row 124

```markdown
| + any design module (`design-tokens` / `design-a11y` / `design-components` in `decided_modules`) | append `&&` followed by the **design-gate resolver fragment** below, verbatim |
```

with

```markdown
| + any design module (`design-tokens` / `design-a11y` / `design-components` in `decided_modules`) | append `&&` followed by the project's **own authoring gate** from § *Design gate* below, verbatim — never `accuracy_report.mjs`, the plugin's self-check, which never tested the project (ADR 005) |
```

Then replace the whole section from the heading `### Design-gate resolver fragment` (line 128) through the end of the paragraph that finishes `instead of waiting for an audit to notice it.` (line 166) with:

````markdown
### Design gate

The gate runs from the kit `npm ci` installs — `node_modules/@roofadvisor/dev-kit/kit`, a
devDependency pinned to a release tag (step 9) — so there is nothing to resolve and nothing to
skip. Appended after `&&`, as `&&`-chained commands, identically in `CLAUDE.md`, the `verify`
script, and `templates/scaffold/verify.yml.tmpl`'s `run:` step:

```sh
&& K=node_modules/@roofadvisor/dev-kit/kit \
&& { [ -f "$K/scripts/build_tokens.mjs" ] || { echo "dev-kit is not installed — run: npm ci"; exit 1; }; } \
&& python3 "$K/scripts/validate_tokens.py" design-tokens.json \
&& python3 "$K/scripts/validate_contrast.py" design-tokens.json \
&& node "$K/scripts/build_tokens.mjs" --in design-tokens.json --out src/theme.css --strict \
&& python3 "$K/scripts/lint_hardcodes.py" src/components
```

It is the project's own gate — validity, contrast, `--strict` unmapped groups, hardcodes — not
the plugin's self-check. It fails, and names the fix, when the kit is absent; it runs for real
in CI because `{{SETUP_CMDS}}` is `npm ci`.

**What this replaced, and why.** Until 2.2.0 this row appended a resolver fragment that found
the plugin through `$CLAUDE_PLUGIN_ROOT` or `~/.claude/plugins/installed_plugins.json` and ran
`accuracy_report.mjs`, printing `design gate: SKIPPED` on a bare runner. Two rationales stood
behind it: that a resolver could not be shipped inside the thing it resolves, and that a CI
design job would mean vendoring the engine plus Playwright into every project. Both were
correct for their premises, and the premises changed: a declared dependency needs no resolver,
and the token gate needs no browser. `docs/decisions/005-kit-as-a-dependency.md` records both
rationales and the change. A project with no `package.json` cannot take a dependency and keeps
the earlier fragment, from that ADR.
````

- [ ] **Step 5: ADR 005**

Create `docs/decisions/005-kit-as-a-dependency.md`:

````markdown
# 005 — The kit is a dependency

- **Status:** Accepted
- **Date:** 2026-09-04

## Context

Every design gate a project can run needs the plugin's `kit/`, and nothing put the kit where a
machine could find it without a human having installed Claude Code first.

- **The authoring gate ran by hand.** roof-club's `design/systems/verify.sh` — validity,
  contrast, coherence, and since 2.1.0 unmapped token groups — is the per-system gate its family
  spec commits to. No CI anywhere ran it; the design-gate line every scaffolded project carried
  was *designed* to print `SKIPPED` on a bare runner.
- **Three resolvers answered one question.** `scripts/_common.py`, the inline `node -e` fragment
  the scaffold-spec copied into every project, and roof-club's own `devkit-path.sh` — already
  different code.
- **Fourteen gate scripts were copied into every project's `.github/scripts/`**, drifting the
  same way, with `framework-upgrade` existing partly to re-sync them.
- **Single-file token mode had never worked.** `project-init` said "seed `design-tokens.json`
  from `kit/tokens/`"; a literal merge builds 70 of 320 variables after seven silent key
  collisions, and no project had ever done it.
- Found on the way: 2.1.0's unmapped-group report had a false negative that hid 30 `spacing`
  tokens; both resolvers accepted any ref by dropping its first segment, which had absorbed a
  typo in `data-viz.json`; `package.json` said 2.0.0 while `plugin.json` said 2.1.0; the
  plugin's own CI ran seven of eleven harnesses.

## Decision

The kit is an installable package. `package.json` is `@roofadvisor/dev-kit` with
`files: ["kit", "scripts", ".claude-plugin"]`; projects pin
`"@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#vX.Y.Z"`; `npm ci` delivers it to
`node_modules/@roofadvisor/dev-kit` on every machine and runner. Gate commands use that fixed
path and **fail — never skip — when it is absent.** Release tags exist so there is something to
pin, and `ship-it` cuts them. The registry gates run from the same `node_modules`; nothing is
copied into a project, and `gates.yml` fails while copies remain. `project-init` scaffolds a
project's *own* authoring gate against a generated, parity-proven seed.

`@roofadvisor/` is npm's scope — the org's namespace, as `dev-kit@roofadvisor` is the plugin
registry's. Two registries, one artifact. The plugin name and install are untouched.

## What this supersedes

Two rationales in `skills/project-init/references/scaffold-spec.md` stand as reasoning that was
right for its premises:

- *"Why this resolution logic is copied into every scaffolded project's verify command, rather
  than shipped once as a plugin script."* A resolver shipped inside the plugin needs the
  plugin's location just to be invoked. True — and moot once the kit is a declared dependency
  at a path the package manager guarantees. There is no resolver to ship.
- *"Why `templates/github/gates.yml` still gets no design job."* Making one work would mean
  vendoring `kit/` plus Playwright and Chromium into every project. True of
  `accuracy_report.mjs` and the render gates, which still stay out of CI. The token gate needs
  neither, and a dependency is not vendoring: nothing is copied into the project.

## Consequences

- github.com joins npmjs.org as something `npm ci` depends on, including on Render (roof-club).
  dev-kit is public, so the fetch is unmetered and no Actions minutes move; it must stay public,
  or consumers need a token.
- A private repository's `gates.yml` now runs `npm ci` before its gates — paid Actions minutes,
  roughly 10–20 s per run with the cache.
- `node_modules` grows by about 1 MB in every consumer.
- Gates resolve the kit through the pin; skills resolve it through the plugin install. A project
  can be pinned to 2.2.0 while a developer's plugin is newer; the gate result is the pinned one.
- A project with no `package.json` keeps the registry fragment and its honest `SKIPPED` until a
  dependency route exists for it.
- The scanners skip dot-directories, so a forgotten `.github/scripts/` copy is invisible to
  them; the assertion in `gates.yml` is load-bearing.
````

- [ ] **Step 6: The spec stops saying "deleted"**

In `docs/superpowers/specs/2026-09-04-kit-as-a-dependency-design.md`, replace in §4.3

```
- **Deleted:** the scaffold-spec's inline `node -e` fragment (§4.5 rewrites the row);
  roof-club's `scripts/devkit-path.sh`, and in its `verify.sh` both the `devkit-path.sh` call
  and the cache-search fallback beneath it — replaced at their call sites (that resolution
  block, `design:lint`, `design:verify`). Cited by content rather than line: those lines have
  moved in each of the last two roof-club PRs, and the migration edits `origin/main`.
```

with

```
- **Deleted:** the scaffold-spec's inline `node -e` fragment (§4.5 rewrites the row), and the
  cache-search fallback in roof-club's `verify.sh`. **Reduced, not deleted:** roof-club's
  `scripts/devkit-path.sh`. The plan found fourteen call sites, not three — ten of them
  render-gate commands in the prototype-completion plan — so the script now prints the fixed
  path or fails naming `npm ci`, and resolves nothing. The principle holds; the file stays.
```

and in §9 replace `scripts/devkit-path.sh (deleted)` with `scripts/devkit-path.sh (reduced to the fixed path)`.

- [ ] **Step 7: Verify and commit**

Run: `bash scripts/verify.sh 2>&1 | tail -3` → `VERIFY PASSED` (`check_instruction_honesty` and `render_instructions` read these skills; a broken fence fails here).

```bash
git add skills/project-init/SKILL.md skills/project-init/references/scaffold-spec.md docs/decisions/005-kit-as-a-dependency.md docs/superpowers/specs/2026-09-04-kit-as-a-dependency-design.md
git commit -m "docs: project-init scaffolds the project's own authoring gate; ADR 005 records the decision

3.7a copies the generated seed instead of describing a merge that never
worked; step 9 adds the pinned devDependency; step 10 says what {{SETUP_CMDS}}
is and why it matters; the gates.yml bullet stops copying scripts. The
scaffold-spec's design-gate row appends the project's own gate — validity,
contrast, --strict, hardcodes — never the plugin's self-check, and its two
rationales are kept in ADR 005 as reasoning that was right for its premises.
The spec now says roof-club's resolver is reduced, not deleted: fourteen
call sites.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: A bare runner installs the kit and runs the scaffolded gate (spec §5, last row)

**Files:**
- Create: `.github/workflows/consumer.yml`

**Interfaces:**
- Consumes: the package (Task 1), the seed (Task 4), the gate command (Task 8), `scripts/` in `files` (Task 7).
- Produces: the first observation of the two assumptions on record — `files` scoping a real git install, and pacote's https fallback on a hosted runner.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/consumer.yml`:

```yaml
name: consumer
# A bare runner installs the kit the way a project does — npm ci from a git ref, no plugin, no
# Claude Code — and runs a scaffolded project's exact authoring gate against the shipped seed,
# then one registry gate the way gates.yml runs it. This is the job that proves the install path
# itself, not just the scripts: `files` scoping a real git install, and a runner with no SSH key
# fetching over https (spec: Assumptions on record).
on:
  push:
    branches: ['**']
  pull_request:

jobs:
  consumer:
    name: "a scaffolded project's gates, from node_modules, on a bare runner"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with: { python-version: '3.12' }
      - uses: actions/setup-node@v4
        with: { node-version: '20' }

      - name: Scaffold a consumer and install the kit at this commit
        run: |
          mkdir consumer && cd consumer
          git init -q && npm init -y >/dev/null
          npm install --no-audit --no-fund "github:roofadvisor/dev-kit#${{ github.sha }}"
          P=node_modules/@roofadvisor/dev-kit
          test -f "$P/kit/scripts/build_tokens.mjs"
          test -f "$P/scripts/check_log_hygiene.py"
          test -f "$P/.claude-plugin/plugin.json"
          # files: scoped the install — the repo's skills/, templates/, tests/ must not be here
          ! test -e "$P/skills"
          ! test -e "$P/templates"
          du -sh "$P"

      - name: Run the exact authoring gate project-init writes (step 7a)
        run: |
          cd consumer
          cp "$GITHUB_WORKSPACE/templates/scaffold/design-tokens.json" design-tokens.json
          mkdir -p src/components
          # lint_hardcodes refuses an empty directory; a scaffolded project has its worked example here
          printf '.btn { color: var(--color-text-primary); padding: var(--space-3); }\n' > src/components/Button.css
          K=node_modules/@roofadvisor/dev-kit/kit
          [ -f "$K/scripts/build_tokens.mjs" ] || { echo "dev-kit is not installed — run: npm ci"; exit 1; }
          python3 "$K/scripts/validate_tokens.py" design-tokens.json
          python3 "$K/scripts/validate_contrast.py" design-tokens.json
          node "$K/scripts/build_tokens.mjs" --in design-tokens.json --out src/theme.css --strict
          python3 "$K/scripts/lint_hardcodes.py" src/components

      - name: Parity with the directory build
        run: |
          want=$(node kit/scripts/build_tokens.mjs --in kit/tokens 2>/dev/null | grep -c '^  --')
          got=$(grep -c '^  --' consumer/src/theme.css)
          echo "directory build: $want lines   seed build: $got lines"
          [ "$want" = "$got" ]

      - name: One registry gate, from node_modules, the way gates.yml runs it
        run: |
          cd consumer
          ! ls .github/scripts/check_*.py >/dev/null 2>&1
          python node_modules/@roofadvisor/dev-kit/scripts/check_log_hygiene.py
```

- [ ] **Step 2: Lint it locally, commit, push, watch it run**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/consumer.yml')); print('yaml ok')"`

```bash
git add .github/workflows/consumer.yml
git commit -m "ci: a bare runner installs the kit from a git ref and runs the scaffolded gate

The job that proves the install path, not just the scripts: files scoping
a real git install, a runner with no SSH key fetching over https, the
shipped seed building at parity from node_modules, and one registry gate
run the way gates.yml runs it. Both assumptions on record in the spec are
observed here for the first time.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
sleep 90
gh run list --workflow consumer --branch "$(git rev-parse --abbrev-ref HEAD)" --limit 1 --json status,conclusion,url --jq '.[0]'
```

Expected: `"conclusion": "success"`. If it fails on the install step with an SSH or fetch error, the pacote assumption did not hold on the runner: switch the pin form to the tarball URL per the spec's *Assumptions on record* and record that in ADR 005's consequences — do not weaken the job. Run `gh run view <id> --log-failed` for the reason.

---

### Task 10: Release 2.2.0, tag it, and land roof-club on the tag (spec §4.8, §8.9)

**Files:**
- Modify: `CHANGELOG.md` (new top entry), `.claude-plugin/plugin.json` (`version`), `package.json` (`version`)
- roof-club: `package.json` (the pin), `package-lock.json`

- [ ] **Step 1: Bump both versions; the harness insists they agree**

Change `"version": "2.1.1"` to `"version": "2.2.0"` in `.claude-plugin/plugin.json` and in `package.json`.

Run: `bash tests/release_test.sh` → `pass=7 fail=0`. (Bump only one and it prints the mismatch — that is the check doing its job.)

- [ ] **Step 2: The changelog**

Insert after `# Changelog` and its blank line at the top of `CHANGELOG.md` (above the 2.1.1 entry):

````markdown
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
  plugin's own CI runs fewer harnesses than `verify.sh` — it ran seven of eleven.
- **Recorded and tested.** ADR 005 supersedes the scaffold-spec's two rationales —
  against vendoring, against a CI design job — as reasoning that was right for its
  premises. A consumer end-to-end job installs the kit on a bare runner from a git ref
  and runs the scaffolded gate, so the install path itself is under test.

Upgrading a project: `framework-upgrade` → *kit as a devDependency (2.2.0)*. Upgrading
the plugin: `claude plugin update dev-kit@roofadvisor`.

````

- [ ] **Step 3: Release commit, merge to main, tag**

Run: `bash scripts/verify.sh 2>&1 | tail -3` → `VERIFY PASSED`.

```bash
git add CHANGELOG.md .claude-plugin/plugin.json package.json
git commit -m "release: 2.2.0 — the kit is a dependency

Minor, not patch: tokens that never emitted before now do, and project-init's
output changes. Consumers pin github:roofadvisor/dev-kit#v2.2.0; every gate runs
from node_modules and fails naming npm ci when the kit is absent. Four builder
bugs, a generated single-file seed proven at parity, the registry gates
un-vendored, and ADR 005 — see CHANGELOG.md.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
git fetch origin
git merge-base --is-ancestor origin/main HEAD && echo "fast-forward"
git push origin HEAD:main
git fetch origin
git tag -a v2.2.0 -m "release: 2.2.0 — the kit is a dependency" "$(git rev-parse origin/main)"
git push origin v2.2.0
gh run list --branch main --limit 3 --json workflowName,conclusion --jq '.[]|"\(.workflowName) \(.conclusion)"'
```

Expected: `fast-forward`; `main-verify success`, `gates success` and `consumer success` on `main`. `git describe --tags --abbrev=0` → `v2.2.0`.

- [ ] **Step 4: roof-club lands on the tag**

```bash
cd /Users/ian-ra/code-projects/RoofAdvisor/roof-club/.worktrees/kit-as-dependency
sed -i '' 's|"@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#[0-9a-f]\{40\}"|"@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#v2.2.0"|' package.json
grep -F '"@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#v2.2.0"' package.json
npm install --no-audit --no-fund
python3 -c "import json;print(json.load(open('node_modules/@roofadvisor/dev-kit/.claude-plugin/plugin.json'))['version'])"   # 2.2.0
env -u KIT HOME="$(mktemp -d)" npm run verify 2>&1 | grep -E "Tests |KIT:|GREEN|Compiled"
git add package.json package-lock.json
git commit -m "chore: pin @roofadvisor/dev-kit to v2.2.0

The interim branch-SHA pin moves to the release tag now that it exists.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git push
N=$(gh pr view --json number --jq .number)
gh pr comment "$N" --body "@codex review — pinned to v2.2.0 now that the tag exists; ready to merge."
```

Read the review with the `original_commit_id` query from roof-club's CLAUDE.md; fix or rebut anything raised against the new commit. Then:

```bash
gh pr merge "$N" --squash --subject "feat: the kit is a devDependency — gates run from node_modules (#$N)"
cd /Users/ian-ra/code-projects/RoofAdvisor/roof-club
git worktree remove .worktrees/kit-as-dependency
git branch -D feat/kit-as-dependency
```

- [ ] **Step 5: Hand off what only the owner can do**

Tell the owner: `claude plugin update dev-kit@roofadvisor` on each machine and relaunch the session (the plugin cache holds 2.1.1; skills use it, gates do not; a running session keeps the hooks it started with); roof-club's main checkout carries their uncommitted Playwright edit and is behind `origin/main` until they commit or set it aside; GHL-MCP migrates via `framework-upgrade` when it adopts a design bundle.

---

## Self-review (run after writing; fixed inline)

**Spec coverage.** §4.1 → Task 1; §4.2 → Task 5; §4.3 → Tasks 6, 8 (amended: reduced, not deleted); §4.4a → Task 4; §4.4b–c → Task 8; §4.4d → Tasks 6, 7; §4.4e → Task 7; §4.5 → Task 8; §4.6 → Task 7 (+ Task 1's `files`); §4.7 B1/B2 → Task 2, B3b/B3 → Task 3; §4.8 → Task 10; §5 rows: release_test → 1, parity → 4, B1/B2/B3b → 2–3, relocation → 7, roof-club HOME-masked → 6, fake-kit tests → 6, consumer end-to-end → 9; §8 steps 1–9 → Tasks 1, 2–3, 4, 5, 6, 7, 8, 9, 10.

**Deviations from the spec, stated:** roof-club's `devkit-path.sh` is reduced rather than deleted (fourteen call sites; Task 8 amends §4.3/§9); `templates/github/gates.yml`'s header is rewritten in Task 7 with its job rather than in Task 8, so one file is edited once; Task 1 also makes the plugin's own CI run every harness (seven of eleven ran; `release_test` asserts the lists agree), a gap found while writing this plan and in scope because a harness green locally and absent in CI is the failure this release exists to end.

**Type consistency.** `colourStem`/`colourClaims`/`colourCovered` (Task 2) are used only within `build_tokens.mjs`; `make_single_file_tokens.mjs --check` exit codes (0/2) match the harness's `check … 0`; the gate command in Task 8's 3.7a, scaffold-spec section, and Task 9's job are the same six lines; the assertion `ls .github/scripts/check_*.py` is identical in Task 7's template, harness, and migration text; `@roofadvisor/dev-kit` and `node_modules/@roofadvisor/dev-kit/kit` are spelled identically in every task; `release_test` counts: 7 checks from Task 1 on; `token_build_test` counts: 17 → 22 → 26 → 29 across Tasks 2–4; `relocation_test`: 14.
