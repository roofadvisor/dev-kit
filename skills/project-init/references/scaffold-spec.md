# Scaffold Spec

Exact layout and content rules. Templates live in `${CLAUDE_PLUGIN_ROOT}/templates/`.

## Init state file

`.claude/.init-state.json` makes `/project-init` resumable. Written after each
completed interview round, updated at plan confirmation and after every scaffold
write, deleted only when Step 4 verification passes. Gitignored (in
`gitignore.tmpl`) — local working state, never shared. This section is the single
source for its shape; do not restate the fields elsewhere.

```json
{
  "mode": "NEW",
  "round": 2,
  "answers": { "company": "F4 Digital", "backend_language": "typescript" },
  "decided_modules": [],
  "preexisting": null,
  "written_files": [],
  "phases": {}
}
```

- `mode` — `NEW` or `RETROFIT`, as confirmed with the user.
- `round` — the last **completed** interview round (0–3). Plan confirmation (Step 2) sets it to `4`.
- `answers` — question-key → answer, accumulated across rounds. Keys are short slugs; the value is the user's settled answer, not the raw reply.
- `decided_modules` — empty until Step 2 approval, then the confirmed module list.
- `preexisting` — **`null` until captured; capture exactly when it is `null`, at entry into Step 3.** `null` means "inventory not taken yet"; `[]` means "taken, and the directory had no planned targets" — the two must never be conflated, because a saved plan writes state (with `null`) before execution, and a resume must never recapture (a file *we* wrote must not be reclassified as pre-existing) while first execution after a saved plan **must** capture (a file created between plan and execution must land in the inventory). This is what lets a resume tell "was here before us" from "our write was interrupted".
- `written_files` — paths whose write **completed**, appended after each write.
- `phases` — non-file steps that completed, e.g. `{"scaffold_commit": true, "baseline_recorded": true, "repo_variable_set": true}`. File writes are not the only resumable work.

Resume rules:

- **Schema check before anything else:** a parseable state file missing fields
  this spec requires (`preexisting`, `phases`) is a legacy or foreign schema —
  treat it exactly like the corrupt case in Step 0: show it, offer
  discard-or-stop. Never default a missing `preexisting` to `[]`; in RETROFIT
  that silently reclassifies every pre-existing target as safe to rewrite.
- Write state after a round completes, never mid-round.
- Skip exactly the files in `written_files`.
- A planned file **not** in `written_files`: if it is in `preexisting`, redo the retrofit-safe operation for it — those operations must be idempotent by construction (append checks for its entries first; `.proposed` files are simply rewritten). If it is not in `preexisting`, rewrite it outright; content is deterministic given `answers`.
- Pre-existing files always stay under the retrofit never-overwrite rules; `written_files` never authorizes replacing one.
- Skip any phase recorded `true` in `phases`. The scaffold commit **must** be recorded — an interrupted run that committed and then resumed would otherwise fail on `nothing to commit`. Idempotent side effects (re-recording the baseline, re-setting a repo variable to the same value) may safely re-run if unrecorded.
- Delete the file only after Step 4 verification passes. Interrupted ≠ failed: both keep the state.

## Target layout (NEW mode)

```
<project>/
├── CLAUDE.md                   # < 80 lines. Loads every turn.
├── README.md                   # human-facing. Different audience, different file.
├── .gitignore
├── .env.example
├── docker-compose.yml
├── scripts/dev-reset.sh
├── .github/workflows/verify.yml
└── .claude/
    ├── settings.json
    ├── rules/                  # selected modules only
    └── agents/                 # selected agents only
```

## .claude/settings.json content (NEW mode)

Exact content — this is the single source for its shape; do not restate it
elsewhere. **Wires only `guard-local.sh`:**

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Read|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/guard-local.sh"
          }
        ]
      }
    ]
  }
}
```

**Never add entries here for `guard.sh`, `rule-zero.sh`, `done-check.sh`,
`format.sh`, `verify-record.sh`, or `session-context.sh` — not even with an
absolute or `${CLAUDE_PLUGIN_ROOT}`-based path.** A18: `${CLAUDE_PLUGIN_ROOT}`
resolves only inside a *plugin's own* `hooks/hooks.json`, never inside a
project's `.claude/settings.json` — a command built from it there is silently
skipped, not run with an empty value (measured on CLI 2.1.220). Those six hooks
are declared exactly once, globally, in the plugin's `hooks/hooks.json`, and
each gates itself on this project's `.claude/.framework-state.json` (step 7)
before doing anything else. Adding a redundant project-level entry for one of
them does not make it "more wired" — at best it duplicates the plugin's own
global firing (extra subprocess per matched tool call, a second
`.enforcement-log` line per real deny), and if written with the broken
`${CLAUDE_PLUGIN_ROOT}` form, it does nothing at all while looking identical to
the working entries. `guard-local.sh` is the one hook that belongs here: it is
copied *into* the project (step 5), so a relative path is correct and is what
makes it survive the plugin being absent entirely.

## CLAUDE.md assembly

From `${CLAUDE_PLUGIN_ROOT}/templates/scaffold/CLAUDE.md.tmpl`. Fill every `{{TOKEN}}`. Leave no placeholder behind.

- `{{ARCH_MAP}}` — 3–8 lines. What the pieces are and how requests flow. No prose paragraphs.
- `{{RULES_INDEX}}` — one line per selected module: `` - `api.md` — HTTP surface, error envelope, versioning ``
- `{{INTEGRATIONS_TABLE}}` — from interview Q5: `| System | Direction | Metered | Adapter |`
- `{{CANONICAL_RULE}}` — from the reconciliation follow-up. If the user had no answer, write: `NOT YET DECIDED — do not build reconciliation logic until this is defined.`

**Hard limit: 80 lines.** If it exceeds that, move detail into a rules module. The file is a router, not a manual.

## Verify command by stack

| Stack | Verify |
|---|---|
| Python only | `uv run ruff check . && uv run mypy . && uv run pytest` |
| TS only | `pnpm typecheck && pnpm lint && pnpm test` |
| Both | chain them with `&&`, Python first |
| + contracts module | append `&& pnpm contracts:check` |
| + blockchain module | append `&& forge fmt --check && forge test && forge snapshot --check` |
| + any design module (`design-tokens` / `design-a11y` / `design-components` in `decided_modules`) | append `&&` followed by the project's **own authoring gate** from § *Design gate* below, verbatim — never `accuracy_report.mjs`, the plugin's self-check, which never tested the project (ADR 005) |

Write it once, identically, in three places: `CLAUDE.md`, the `verify` script, and the CI workflow. If they can drift, they will.

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

## Toolchain pins

```bash
# Python
uv init --python 3.12
uv add --dev ruff mypy pytest hypothesis

# TypeScript
corepack enable && corepack use pnpm@latest

# Solidity (blockchain module only)
curl -L https://foundry.paradigm.xyz | bash && foundryup
```

Commit `.python-version`, `uv.lock`, `packageManager` in package.json, `pnpm-lock.yaml`, `foundry.toml`.

## Seed data requirements

A seed that only contains happy-path rows is worse than none — it teaches Claude the schema is simpler than it is. Every seed includes:

- A row with nulls in every nullable column
- A unicode name and an apostrophe in a text field
- A soft-deleted row, if soft delete exists
- Two rows from different sources describing the same real entity, if data-integration is enabled
- A record at the boundary of every constraint (max length, zero, negative where allowed)
- If storage: one small file, one at the size limit, one with a unicode filename

## Commit sequence

```bash
git init
git add -A
git commit -m "chore: project scaffold via dev-kit"
```

One commit. Do not split the scaffold across several.

## RETROFIT specifics

- Write `CLAUDE.md.proposed`, never overwrite.
- Detect and adopt: package manager (lockfile present), indent style, existing test runner, existing lint config. The template yields to reality.
- Add `.claude/` even if nothing else changes — that alone is most of the value.
- Do not add docker-compose if the repo already has a working local setup. Document the existing one in CLAUDE.md instead.
