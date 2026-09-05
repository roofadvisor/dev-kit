---
name: framework-upgrade
description: Move a project from an older dev-kit version to the current one — diff its .claude/ against the plugin, classify each difference, apply what is safe, and surface conflicts. Use when a repo is behind on plugin version, when /project-audit reports drift, after the framework ships a new version, or when the user says "update the framework", "sync the rules", or "this repo is on an old version".
---

# Framework Upgrade

The framework's promise is *"we are always working on the same system."* Without
this skill that promise decays silently — every repo keeps working while slowly
diverging, and nobody notices because nothing breaks.

## Run the diff first, always

```bash
python3 "$CLAUDE_PLUGIN_ROOT/scripts/upgrade.py" --plugin "$CLAUDE_PLUGIN_ROOT"
```

Dry run by default. It classifies every managed file five ways:

| Class | Meaning | Action |
|---|---|---|
| `UNCHANGED` | Identical | none |
| `FRAMEWORK` | Plugin changed, project untouched | safe to apply |
| `LOCAL` | Project customized, plugin unchanged | **keep** — never overwrite |
| `CONFLICT` | Both changed | human decides |
| `NEW` | Plugin has a file the project lacks | offer, do not assume |
| `ORPHAN` | Plugin dropped a rule the project still holds | flag, never auto-delete |

## Apply

```bash
python3 "$CLAUDE_PLUGIN_ROOT/scripts/upgrade.py" --plugin "$CLAUDE_PLUGIN_ROOT" --apply
```

Writes `FRAMEWORK` only. Add `--accept-new` after reviewing what `NEW` would
install — a new module the project does not need is context cost on every turn.

## Conflicts

**Never resolve a conflict by taking the framework wholesale.** That silently
deletes a project-specific rule someone added for a reason, and the deletion is
invisible afterward.

For each conflict, ask: is the local change still wanted?
- **Yes** → merge the framework's addition into the local version by hand
- **No** → take the framework version and note the removal in `docs/log.md`
- **It generalizes** → run `/promote-rule` to lift it into the plugin, then take the framework version

## Orphans

A rule the plugin dropped but the project still holds. Usually means the rule was
demoted framework-wide but is still load-bearing here — or that it is genuinely
dead. Ask, then either keep it as a documented local rule or remove it with a note.

## Named migrations

Version-specific reshapes the generic classification above cannot express on
its own — the mechanical diff can only call the old side `ORPHAN` and the new
side `NEW`, which is technically true and not useful on its own. Check this
list before resolving either.

**`frontend` → design modules (2.0.0).** A manifest listing `frontend` predates
the split. Ask which design capabilities the project actually has, then replace
that entry with the matching `design-*` ids and copy the modules in. Do not map
`frontend` to all four silently — it was six bullets, and the four modules
assert far more than it did.

This migration does not, and does not need to, write `bundles` into
`.claude/.framework-state.json` — that field is `/project-init`'s own record
of the interview's raw Round 3 answer, and this path never runs that
interview. `/project-audit`'s Design section does not depend on it either: it
gates on `bundles` being non-empty **or** any `design-*` module existing in
`.claude/rules/`, so a project that arrived here via this migration is
audited correctly from the modules this step just copied in, with no
declaration step to remember or skip.

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

## After applying

1. Run the project verify command. An upgrade that breaks verify is not done.
2. Run `/project-audit` — specifically the registry-honesty check, since new rules
   may claim enforcement this repo has not wired.
3. Bump the pinned version and commit it on its own:
   ```bash
   git add .claude
   git commit -m "chore: upgrade dev-kit to <version>"
   ```
   Its own commit, so a bad upgrade reverts cleanly without taking feature work with it.

## Cadence

Monthly, alongside `/project-audit`. A repo more than two minor versions behind
should be upgraded before any new feature work — otherwise you are writing code
against rules the framework no longer holds.
