# The kit is a dependency — design

- **Status:** approved 2026-09-04 (owner review; un-vendoring folded in, §4.6). Plan: `docs/superpowers/plans/2026-09-04-kit-as-a-dependency.md`
- **Date:** 2026-09-04
- **Release:** dev-kit 2.2.0 (minor)
- **Records the decision as:** `docs/decisions/005-kit-as-a-dependency.md` (written in this release)
- **Supersedes:** `skills/project-init/references/scaffold-spec.md` § *Why this resolution logic is copied into every scaffolded project's verify command* and § *Why `templates/github/gates.yml` still gets no design job*; `templates/github/gates.yml` lines 5–13

## 1. Problem

Every design gate a project can run needs the plugin's `kit/`, and nothing puts the kit
where a machine can find it without a human having installed Claude Code first.

Three consequences, each observed rather than inferred:

1. **The authoring gate runs by hand.** `design/systems/verify.sh` in roof-club — validity,
   contrast, coherence, and since 2.1.0 unmapped token groups — is the per-system gate the
   family spec §9 commits to. Until PR #97 it ran only when someone typed it; #97 wired it into
   `npm run verify`, where it still depends on a plugin cache existing on that machine. No CI
   anywhere runs it. The scaffold-spec recorded the reason: a bare GitHub Actions runner has
   neither `$CLAUDE_PLUGIN_ROOT` nor `~/.claude/plugins/installed_plugins.json`, so the
   design-gate line every scaffolded project carries is *designed* to print `SKIPPED` there.
2. **Three resolvers exist for one question.** `scripts/_common.py` (`plugin_registry_path`,
   for the plugin's own checks); the inline `node -e` fragment the scaffold-spec copies verbatim
   into every project's verify command; and roof-club's bespoke `scripts/devkit-path.sh`
   (registry, then caches, with its own version comparison and orphan handling). They are
   already different code. The scaffold-spec argued this copying was unavoidable — a resolver
   shipped inside the plugin needs the plugin's location just to be invoked — and that argument
   was correct for its premise.
3. **Single-file token mode has never worked, and nothing could tell.** `project-init` step
   3.7a tells the agent to write `design-tokens.json` "seeded from `kit/tokens/`". No seed file
   exists; no `design-tokens.json` exists in any repository on this machine; and a literal flat
   merge of `kit/tokens/*.json` builds **70 of 320** custom properties, after seven silent
   top-level key collisions (`semantic` twice, `grid`, `surface`, `disabled`, `selected`,
   `focus`) hand the colour emitter chart colours where it expects text and surfaces.

The plugin's stated purpose is to enforce good practice for a solo developer or a team with the
design system living beside the code. A gate that cannot run in CI, a seed that cannot build,
and a check with a false negative (found on the way — §4.7) are each the pattern this session
kept meeting: a check that cannot fire, failing nowhere.

## 2. The decision

The kit becomes an **installable dependency**. Projects pin it in `package.json`; `npm ci`
delivers it to `node_modules/@roofadvisor/dev-kit/kit` on every machine and every runner; gate
commands use that fixed path and **fail — never skip — when it is absent**. Release tags exist
so there is something to pin. `project-init` scaffolds a project's *own* authoring gate against
a *verified* single-file seed. Four bugs the investigation surfaced ship in the same release,
because the gate being scaffolded has to be trustworthy first.

The scaffold-spec's two rejections — of vendoring the engine into every project, and of a
design job in CI — stand as reasoning. Their premises no longer hold: nothing is copied into a
project (the kit lives in `node_modules`, pinned), the token gate needs neither Playwright nor
Chromium, and once the kit is a declared dependency its absence is under the project's control
rather than an external precondition. That is why `SKIPPED` becomes a failure.

## What this does not change

Stated here because the first review read it otherwise.

- **The Claude Code plugin install.** `dev-kit@roofadvisor` in `installed_plugins.json` — the
  skills, hooks, and agents — is not touched. Nothing is uninstalled or reinstalled in any
  project. Skills keep resolving `${CLAUDE_PLUGIN_ROOT}` through the registry exactly as today.
- **What dev-kit is.** Its own repository, its own plugin. `@roofadvisor/` in the package name is
  npm's *scope* — the org's namespace, the same org that owns `@roofadvisor/roof-club` — not a
  relationship to any project. The plugin registry spells the same artifact `dev-kit@roofadvisor`;
  npm spells it `@roofadvisor/dev-kit`. Two registries, one thing.
- **A consuming project's application.** The devDependency is never imported by app code. In
  roof-club, `prebuild` stays plugin-free and the app bundle is unchanged; the only thing Render
  sees is a ~3 s fetch during `npm ci` (§6).
- **Work in progress.** A project migrates in one small PR from a worktree — one devDependency
  line, the `KIT` path in its `verify.sh`, its resolver script deleted — at a moment of its
  choosing. Before that PR its gates resolve as today; after it, by the fixed path. There is no
  window in which either fails.

The two copies coexist by design: the plugin cache for Claude, `node_modules` for the gates,
pinned independently (§6).

## 3. What was measured

Every claim below was run, not read, on 2026-09-04 against `e7aa5f8` (2.1.0).

| Question | Result |
|---|---|
| Does a git-ref install work today? | `npm install github:roofadvisor/dev-kit#e7aa5f8` → 1 package, 3 s, 2.3 M (whole repo — no `files` field), `.claude-plugin/plugin.json` present, Playwright **not** pulled transitively |
| Do the gate scripts run from `node_modules`? | `build_tokens.mjs` emits 389 lines / 320 unique names from its own tokens; `validate_tokens.py` passes. `kit/scripts` imports nothing beyond node built-ins; the python validators use `pathlib`, `json`, `re`, `sys` only |
| Does `files` scope a git install? | `files: ["kit", ".claude-plugin"]` → `npm pack`: 218 kB packed, **759 kB unpacked, 137 files**. npm packs a git checkout the same way (it warned it was using `.gitignore` in the absence of `.npmignore`) |
| Is the lock CI-safe? | The lock records `git+ssh://git@github.com/…#<full sha>` whatever URL form is given — even `git+https://`. With `GIT_SSH_COMMAND=/usr/bin/false` and an empty cache, `npm ci` **exits 0**: pacote falls back to https for hosted repos |
| Tarball form (`…/archive/<sha>.tar.gz`)? | Also works, with a sha512 integrity; but `files` is not applied (2.3 M), and GitHub archive checksums are not a stable pin. **Git-ref chosen** |
| Tags? | None. Releases are `release:` commits touching `plugin.json` and `CHANGELOG.md`. `ship-it` §6 already calls `git describe --tags --abbrev=0`, which fails with no tags |
| Version drift? | `package.json` says `2.0.0`, `plugin.json` says `2.1.0` |
| Does the npm name matter anywhere? | Only `package.json` and the lock's root name. `plugin.json` / `marketplace.json` `name: dev-kit` is the *plugin* name — a separate namespace, unchanged |
| Single-file layouts | flat merge: 70/320. One key per source file: the colour emitter finds no top-level `semantic`. Colour tiers hoisted + others keyed by stem: **284/320**; the 36 missing are composites whose intra-file refs (`{fontSize.2xl}`, `{easing.spring}`, `{width.thin}`) stop resolving once wrapped — 23 in `typography.json`, 3 in `motion.json`, the rest in `borders.json` and `data-viz.json` |
| Directory layout under file-scoped colour claims | `spacing.semantic.*` — **30 tokens** (page 4, card 3, stack 6, inline 4, component 13) — emit nothing and are hidden by 2.1.0's bare `semantic` claim; the output has zero `--space-page/stack/inline/card/component` |
| `data-viz.json` | Two refs to `{dataviz.…}`; the file is `data-viz`. Both resolvers accept it by stripping a ref's first segment unconditionally |
| roof-club | Not touched by the false negative (`foundation.json` has no colour-tier key). Its `verify.sh` min-version check reads `$KIT/../.claude-plugin/plugin.json`, which `files` ships |
| Registry gates relocated to `node_modules` | In a synthetic consumer (git-initialised, `.claude/rules/`, sources, kit under `node_modules`): `check_guess_lists`, `check_statelessness`, `check_log_hygiene` exit 0 with **zero findings inside `node_modules`**; `render_instructions.py --check` exits 0 (it takes `--rules-dir`; needs no `_common`); a planted `console.log(user.password)` is caught from the relocated copy. No script edits: each finds `_common.py` beside itself and takes the repo root from git or cwd |
| Are stale `.github/scripts/` copies self-flagged? | **No.** The walkers skip every dot-directory, so `.github/` is invisible to them — which is also why the vendored copies never tripped the scanners. A forgotten copy needs its own assertion (§4.6) |
| The relocated copy run inside the *plugin's own* repo | flags the scanner's in-repo twin — each excludes itself by `__file__`, and the twin is a different path. An artifact of that test, not of relocation; recorded so nobody repeats it |

## Assumptions on record

Two things §3 measured by proxy, which the consumer end-to-end job (§5) is the first to observe
directly:

- **`files` scopes a git install** the way it scopes `npm pack`. Observed as `npm pack --dry-run`
  inside an installed copy after adding the field, and as npm's own warning that it applies
  `.gitignore` rules to a git checkout — not yet as a git install of a commit that carries
  `files`, because none exists until §4.1 lands.
- **pacote's https fallback** was observed on this machine with SSH forced to fail, not on a
  hosted runner. `ubuntu-latest` has no key for github.com by default, which is the same
  condition; the job confirms it.

If either fails there, the design holds and only the pin form changes: the tarball URL (§3) is
the fallback, at the cost of `files` scoping.

## 4. Design

### 4.1 The package (A) and version hygiene (F)

`package.json`:

```json
{
  "name": "@roofadvisor/dev-kit",
  "version": "<mirrors .claude-plugin/plugin.json>",
  "private": true,
  "files": ["kit", "scripts", ".claude-plugin"],
  "devDependencies": { "playwright": "^1.62.1" }
}
```

- `@roofadvisor/dev-kit` matches the org's existing `@roofadvisor/roof-club`. The install path
  becomes `node_modules/@roofadvisor/dev-kit`; the lock's root name is regenerated. The scope is
  not decorative: an unscoped `dev-kit` already exists on npm (an Angular 2 package, `1.0.0-beta2`),
  and a bare name would collide in any tooling that consults the registry. The scope is the org,
  not a project — see *What this does not change*.
- `private: true` stays. It blocks `npm publish`; it does not block git installs (measured).
- The Playwright devDependency stays for the plugin's own render gates. Consumers do not
  inherit devDependencies (measured).
- `files` ships `kit/` whole (the render scripts and `accuracy_report.mjs` reach `kit/examples`),
  `scripts/` (the registry gates and `render_instructions.py` — §4.6, about 220 kB more), and
  `.claude-plugin/` so the one version-read path — `$KIT/../.claude-plugin/plugin.json` — works
  identically from a plugin cache and from `node_modules`.

Consumers pin by tag:

```json
"devDependencies": { "@roofadvisor/dev-kit": "github:roofadvisor/dev-kit#v2.2.0" }
```

npm resolves the tag to a commit at install time and records the SHA in the lock; `npm ci`
reproduces it and survives a runner with no SSH key (measured). Two costs stated plainly:
759 kB / 137 files in every consumer's `node_modules`, and any deploy that runs `npm ci` —
roof-club's Render build does — now fetches from github.com as well as npmjs.org.

**F.** `tests/release_test.sh`, in `scripts/verify.sh`'s harness loop, asserts: the two
`version` fields are equal; `name` is `@roofadvisor/dev-kit`; `files` contains exactly `kit`,
`scripts` and `.claude-plugin`. `ship-it` §6 runs the same assertions before tagging. F lands first, as
its own commit, because the drift is live now.

### 4.2 Tags (B)

- Backfill annotated tags on the commits already on `origin/main` that set each version:
  `v2.0.0` → `57fc95f` (the merge that set 2.0.0), `v2.0.1` → `9c52b0d`, `v2.1.0` → `e7aa5f8`.
  Tags do not rewrite history; `git describe` starts working the moment they exist.
- `ship-it` §6 keeps its policy — *tag after merge, never before, and only on explicit
  confirmation* — and gains the command that enacts it:
  `git tag -a v<X.Y.Z> -m "release: <X.Y.Z> — <title>" <release commit> && git push origin v<X.Y.Z>`,
  preceded by `bash tests/release_test.sh`.
- `v2.2.0` is the first tag cut by the process rather than backfilled.

### 4.3 Resolution (C)

Gate commands stop resolving. The kit is at `node_modules/@roofadvisor/dev-kit/kit`, or it is
not there and the gate fails with the one instruction that fixes it: `npm ci`. The presence
check is `kit/scripts/build_tokens.mjs`, not the directory (PR #97 found an empty `KIT` passing
`-d`). A `KIT` environment override remains, for tests and for a checkout of the plugin itself.

This is a smaller design than the "one shipped resolver with a `node_modules` fallback" the
brainstorm first proposed, and more unified: the bootstrap problem the scaffold-spec described
is solved by `npm ci`, which every Node project already runs, so no resolver is needed for
gates at all.

What goes, what stays:

- **Deleted:** the scaffold-spec's inline `node -e` fragment (§4.5 rewrites the row), and the
  cache-search fallback in roof-club's `verify.sh`. **Reduced, not deleted:** roof-club's
  `scripts/devkit-path.sh`. The plan found fourteen call sites, not three — ten of them
  render-gate commands in the prototype-completion plan — so the script now prints the fixed
  path or fails naming `npm ci`, and resolves nothing. The principle holds; the file stays.
- **Kept:** `scripts/_common.py`'s `plugin_registry_path()`. It answers a different question —
  what Claude Code has installed — which `project-audit` needs, and which skills' prose
  `${CLAUDE_PLUGIN_ROOT}` references continue to mean. Gates use the pinned copy; skills use
  the installed plugin. Reporting drift between the two is a follow-on (§7).
- **Limit:** a project with no `package.json` cannot take a devDependency. Python-only projects
  keep the registry fragment, and the ADR says so. Every design-gate invocation already assumed
  `node`, so this excludes no project that could run the gates before.

### 4.4 project-init (D)

**(a) A verified seed replaces a procedure.** New `kit/scripts/make_single_file_tokens.mjs`
generates `templates/scaffold/design-tokens.json` from `kit/tokens/`:

1. `colors.json`'s top-level tiers (`primitive`, `semantic`, `component`, `dark`) are hoisted to
   the top level — the colour emitter reads them there in single-file mode
   (`build_tokens.mjs:74`). No other source file's stem collides with those names.
2. Every other file is keyed by its stem: `typography`, `spacing`, `borders`, `shadows`,
   `motion`, `breakpoints`, `gradients`, `opacity`, `blur`, `sizing`, `states`, `theming`,
   `data-viz`. These are exactly the directory-form paths `GROUPS` already reads.
3. Refs are rewritten so both resolvers agree: inside a non-colour file, `{x.y}` where `x` is a
   top-level key of that same file → `{<stem>.x.y}`; `{../colors.p}` → `{p}`;
   `{../<other>.p}` → `{<other>.p}`. Refs already qualified are left alone.
4. A `$schema` and a `$description` naming the generator and the regeneration command.

The seed is a committed artifact. Its truth is a **parity test**: the single-file build must
emit exactly the directory build's set of custom-property names; `--strict` must be clean;
`validate_tokens.py` and `validate_contrast.py` must pass on it. The same three commands are
added to `accuracy_report.mjs`'s `CHECKS`, so seed drift fails `/gate` — the plugin's own
self-check — not a downstream project.

**(b) 3.7a copies the seed** instead of describing one. The project then replaces
`primitive.brand`, as today. The scaffold-spec's design-gate row (line 124) stops appending
`accuracy_report.mjs` — the plugin's self-check, whose own rationale concedes it never tested
the project — and appends the project's **own** authoring gate, via the fixed path, in this
order, chained with `&&` as the scaffold-spec renders every `{{VERIFY}}` step:

```sh
K=node_modules/@roofadvisor/dev-kit/kit
[ -f "$K/scripts/build_tokens.mjs" ] || { echo "dev-kit is not installed — run: npm ci"; exit 1; }
python3 "$K/scripts/validate_tokens.py" design-tokens.json
python3 "$K/scripts/validate_contrast.py" design-tokens.json
node "$K/scripts/build_tokens.mjs" --in design-tokens.json --out src/theme.css --strict
python3 "$K/scripts/lint_hardcodes.py" src/components
```

Fail, never skip. `src/components` is the scaffold's component directory; step 9 substitutes the
project's own if it differs.

**(c) Step 10 documents `{{SETUP_CMDS}}`**, which today has no source anywhere in the plugin:
for a Node project it is `npm ci`. That line is where CI receives the kit; `verify.yml.tmpl`
itself does not change.

**(d) A named migration in `framework-upgrade`**, in the prose form the existing
*"`frontend` → design modules (2.0.0)"* entry uses — *"kit as a devDependency (2.2.0)"*:
add the pinned devDependency; delete the inline fragment, or reduce `devkit-path.sh` to the fixed path, and repoint its
call sites; delete `.github/scripts/check_*.py` and `render_instructions.py` and repoint
`gates.yml` (§4.6); confirm the CI setup runs `npm ci`; run the project verify (an upgrade that
breaks verify is not done). roof-club migrates first, in this release; GHL-MCP when it adopts a
design bundle.

**(e) `templates/github/gates.yml`** keeps no design job. Its header comment (lines 5–13) is
rewritten: the design gate runs in `verify.yml`'s Verify step, and now runs for real there. The
registry gates it does run come from `node_modules` (§4.6).

### 4.5 The decision record (E)

`docs/decisions/005-kit-as-a-dependency.md`, in the house ADR shape (`# 005 — …`, Status,
Date, Context, Decision, Consequences). Context: the three resolvers; fourteen gate scripts copied into every project; no automated
authoring gate anywhere; 62 dead tokens found by 2.1.0 and 30 more hidden from it; single-file
mode never exercised. Decision: §2. Consequences: §6. And a section the format does not usually
need — *what this supersedes* — quoting the two scaffold-spec rationales and stating which
premise each rested on and why it no longer holds, so the earlier reasoning is preserved as
correct-for-its-time rather than deleted as wrong.

The scaffold-spec's three paragraphs (lines 156–166) and the row at line 124 are rewritten to
state the new rule and point at the ADR.

### 4.6 The registry gates come the same way

`project-init` copies fourteen `check_*.py` and `render_instructions.py` into a project's
`.github/scripts/`, and `templates/github/gates.yml` runs `python ".github/scripts/$1"`. Those
copies drift exactly as the three resolvers did, and `framework-upgrade` exists partly to re-sync
them. With the kit a dependency, the copying stops:

- `files` ships `scripts/` (§4.1).
- The `gates.yml` template gains `actions/setup-node` with `cache: npm` and an `npm ci` step, and
  runs `python node_modules/@roofadvisor/dev-kit/scripts/$1`. `check_commits` and
  `check_test_count` keep their `BASE_REF`; nothing else about the jobs changes.
- `project-init` step 10 stops copying into `.github/scripts/`; the directory is not created.
- The `framework-upgrade` migration (§4.4d) deletes a project's copies **and asserts they are
  gone** — one line in the migration and in `gates.yml`: `! ls .github/scripts/check_*.py`. The
  assertion is necessary, not belt-and-braces: the walkers skip dot-directories, so a forgotten
  copy is invisible to every scanner (§3).
- No script changes. Each scanner locates `_common.py` beside itself and the repo root from git
  or cwd; `render_instructions.py` takes `--rules-dir`. Measured in a synthetic consumer (§3) and
  pinned by the relocation test (§5).

Cost, stated for the person paying: a private repository's `gates.yml` now runs `npm ci` — paid
Actions minutes, roughly 10–20 s per run with the cache. roof-club has no `gates.yml`. Public
repositories pay nothing.

### 4.7 Bugs shipped in the same release

Each is on the critical path: §4.4 scaffolds a gate that uses `--strict`, and `--strict` has to
be telling the truth first.

- **B1 — a false negative in 2.1.0's coverage check.** `claimed` seeds the colour tiers by
  bare name (`'primitive', 'semantic', 'component', 'dark'`), so a top-level `semantic` in
  *any* file reads as covered. Fix: the four colour-tier claims become `<colour stem>.<tier>` — `colors.` in directory
  mode, the file's own stem in single-file mode — and match a leaf's `full` form only; `GROUPS`
  claims keep matching either form, as before.
  Regression test: a non-colour file with an unmapped top-level `semantic` group is reported.
- **B2 — 30 dead tokens.** `spacing.semantic.*` gets `[['spacing.semantic'], 'space-']` →
  `--space-page-inline-padding`, `--space-stack-md`, `--space-component-button-padding-x`.
  Nothing in `kit/` or `templates/` consumes any such name today, and the sub-group names are
  alphabetic where the scale's keys are numeric, so nothing collides.
- **B3 — the typo.** `data-viz.json` lines 37–38: `{dataviz.diverging.positive-strong}` and
  `…negative-strong}` → `{data-viz.…}`.
- **B3b — the accident that hid it.** `build_tokens.mjs`'s `res()` falls back to
  `ref.split('.').slice(1)`; `validate_tokens.py` to `norm.split(".", 1)[-1]` and then to
  `any(k.endswith(norm))`. Any first segment passes. New rule in both: a ref `{a.rest}` resolves
  if `a.rest` is a key, or if `a` is the stem of a source file and `rest` is a key. Nothing
  else. The `endswith` match is removed. Regression test: a ref into a namespace that is not a
  file stem is rejected by both, and every existing token set — the kit's, the seed, roof-club's
  three systems — still resolves.

### 4.8 Release — 2.2.0

Minor, not patch: a new install surface, 30 newly emitted variables, changed `project-init`
output. Not major: every registry-resolved gate keeps working for an un-migrated project, and
no emitted name changes. `CHANGELOG.md` entry in the house voice (framing paragraph, bolded-lead
bullets with the numbers, upgrade line). Tagged `v2.2.0` by §4.2's step after merge.

## 5. Testing — what makes this true

| Test | Proves |
|---|---|
| `tests/release_test.sh` | versions match, name, `files` |
| Parity test (`tests/token_build_test.sh`, extended) | single-file seed ≡ directory build; `--strict` clean; both validators pass |
| B1 regression | an unmapped `semantic` in a non-colour file is reported |
| B2 | the 30 `--space-*` names emit; no name collides with the scale |
| B3b regression | a fake-namespace ref fails in `build_tokens.mjs` and `validate_tokens.py`; all known token sets still build |
| Relocation test (`tests/relocation_test.sh`) | in a synthetic consumer, the three registry gates and `render_instructions.py` run from `node_modules`: silent on a clean tree with zero findings inside `node_modules`; a planted `console.log(user.password)` is caught; the `.github/scripts/` absence assertion fails when a copy is planted |
| roof-club, migrated | `npm run verify` green with **no** plugin cache on the path (`KIT` unset, `~/.claude/plugins` masked in the test env) — the real CI simulation |
| roof-club fake-kit tests | still pass: an empty `KIT` fails naming `npm ci`; a 2.0.1 kit is refused |
| **Consumer end-to-end**, a job in the plugin's own `.github/workflows/` | on a bare `ubuntu-latest`, with `actions/setup-python` 3.12 as `gates.yml` already uses: `npm init -y`, install `github:roofadvisor/dev-kit#${{ github.sha }}`, copy the seed to `design-tokens.json`, run §4.4(b)'s exact command, assert exit 0 and that `src/theme.css` carries the parity count of variables; then run one registry gate from `node_modules` the way the `gates.yml` template does |

The last row is the one this spec exists for. It would have caught "3.7a never worked" the day
3.7a was written, and it will catch the next seed, gate, or install regression on the pull
request that introduces it.

## 6. Consequences and limits

- github.com joins npmjs.org as something `npm ci` depends on, including on Render. **What that
  entails, measured:** dev-kit is public, and a public repository's git fetch over https is not
  metered by GitHub — it is not an Actions run, and public-repo bandwidth is not billed (Git LFS
  would be; none is used). The GitHub bill does not move. On Render it is the ~3 s the install
  took in §3, per deploy. The real costs are two couplings: github.com must be reachable at deploy
  time, and **dev-kit must stay public** — were it made private, `npm ci` on Render would need a
  token. Noted in the ADR and the roof-club migration.
- The kit fetch itself adds no Actions minutes anywhere: roof-club gains no workflow, and the
  consumer end-to-end job (§5) runs in dev-kit's own repository, which is public and free. A
  private repository that already runs `gates.yml` pays for the `npm ci` that now precedes its
  registry gates — roughly 10–20 s per run with the cache (§4.6).
- `node_modules` grows by 759 kB in every consumer.
- Contributors must `npm ci` before `npm run verify` — already true for any Next project.
- Gates and skills resolve the kit differently from now on: gates use the pinned copy, skills
  use the installed plugin. A project can be pinned to 2.2.0 while a developer's plugin is
  2.3.0; the gate result is the pinned one, which is what pinning is for.
- Python-only projects keep the registry fragment and its `SKIPPED` behaviour until a
  dependency route exists for them.
- B3b tightens what both resolvers accept. A token set relying on a first segment that is not
  a file stem stops resolving; every known set — the kit's, the seed, roof-club's three systems —
  is tested against the rule before it ships, and the error names the ref.

## 7. Non-goals and follow-ons

- **npm publish.** `private: true` stays; git-ref pinning is sufficient and reproducible.
- **A Python dependency route** for projects with no `package.json`.
- **Render gates in CI** (`measure_render`, axe, focus-trap). They need Playwright and Chromium;
  the scaffold-spec's rejection of that stands.
- **`project-audit` reporting installed-vs-pinned drift.** `_common.py` is kept so this can be
  added; it is not in this release.
- **Tightening beyond the stem rule** in either resolver.

## Open

Nothing blocking. The two assumptions on record are the only things not yet observed end to
end, and the job that observes them is in scope.

## 8. Sequencing for the plan

Each step ends green on its own validators; a `SKIPPED` gate is never a passed gate.

1. **F** — `release_test.sh`, package fields, wired into verify. Own commit.
2. **B1 + B2** in one commit, then **B3b + B3** in one commit. Each fix reveals the bug paired
   with it — the coverage fix reports the 30 `spacing.semantic` tokens, the stem rule rejects the
   typo — so a commit holding only the first half would leave the kit's own gate red. Each
   regression test is written first and seen to fail.
3. **Seed + parity test + `/gate` checks** (§4.4a).
4. **Tags** (§4.2) — backfill, `ship-it` step.
5. **roof-club migration** (§4.3, §4.4d) — its verify green with no plugin cache reachable.
6. **Un-vendor the registry gates** (§4.6) — `files`, the `gates.yml` template, `project-init`
   step 10, the migration's delete-and-assert, and the relocation test.
7. **project-init, scaffold-spec, `gates.yml`, ADR 005** (§4.4b–e, §4.5).
8. **Consumer end-to-end job** (§5, last row).
9. **CHANGELOG, `release: 2.2.0`, merge, `v2.2.0`.**

## 9. Files touched

- `package.json`, `package-lock.json` (regenerated), `tests/release_test.sh`,
  `tests/relocation_test.sh` (new), `scripts/verify.sh`
- `kit/scripts/build_tokens.mjs`, `kit/scripts/validate_tokens.py`, `kit/tokens/data-viz.json`,
  `tests/token_build_test.sh`
- `kit/scripts/make_single_file_tokens.mjs` (new), `templates/scaffold/design-tokens.json` (new),
  `kit/scripts/accuracy_report.mjs`
- `skills/ship-it/SKILL.md`, `skills/project-init/SKILL.md` (3.7a, steps 9–10),
  `skills/project-init/references/scaffold-spec.md` (row 124, §§ at 156–166),
  `skills/framework-upgrade/SKILL.md` (named migration), `templates/github/gates.yml` (header, `npm ci`, gate path)
- `docs/decisions/005-kit-as-a-dependency.md` (new), `CHANGELOG.md`, `.claude-plugin/plugin.json`
- `.github/workflows/` — the consumer end-to-end job
- roof-club: `package.json`, `design/systems/verify.sh`, `scripts/devkit-path.sh` (reduced to the fixed path),
  `docs/specs/2026-08-31-design-system-family.md` (authoring-gate paragraph)
