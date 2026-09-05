---
name: ship-it
description: Prepare work for merge and release — run the right audit agents, check the Definition of Done, write the rollback step, bump the version, and update the changelog. Use when the user says "ship it", "ready to merge", "open the PR", "cut a release", or when a branch is finished and needs to go out.
---

# Ship It

## 1. Verify

Run the project verify command. If it fails, stop. Report the failing check, not a summary.

## 2. Audit agents

Run only what the diff touches:

| Diff touches | Agent |
|---|---|
| A migration | `schema-reviewer` |
| An external source or adapter | `integration-auditor` |
| A shared payload, event, or endpoint | `contract-drift-checker` |
| Always | `verify-runner` |

Report findings before proceeding. UNSAFE or BREAKING findings block the PR.

## 3. Definition of Done

Walk `${CLAUDE_PLUGIN_ROOT}/templates/process/DEFINITION.md`. If the project
carries `.claude/rules/design-handoff.md`, walk its Definition of Done too.
Report each unmet item explicitly — never silently pass one.

## 4. Rollback

Write the actual undo path. Test the claim:
- Migration ran? Then "revert the commit" is false. Describe the real path.
- Feature-flagged? The rollback is the flag, and that's a good answer.
- Data written that a revert would orphan? Say so.

## 5. PR

Draft first, then stop. Stage explicit paths — never `git add -A`, which sweeps
untracked and generated files.

```bash
git add <explicit paths>
git commit -m "<type>(<scope>): <summary>"
```

Fill the PR body from `${CLAUDE_PLUGIN_ROOT}/templates/process/PR.template.md` and show it. Then ask
before doing anything outward-facing:

```bash
git push -u origin <branch>
gh pr create --title "<type>(<scope>): <summary>" --body-file <drafted body>
```

Push and PR creation are hard to walk back. Run them only on an explicit yes.

## 6. Release, if this is one

- List the commits since the last tag, so the changelog describes what actually
  changed: `git log --oneline "$(git describe --tags --abbrev=0)"..HEAD`
- Read the diff and **propose** the semver level with your reasoning. A breaking
  API or payload change is major — argue it rather than assume it. Wait for a yes.
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

## 7. Work DB

The sync handles `State`, `PR URL`, `Branch`, `Commit`, and `Merged` on its own — do not write them.

Do write, if not already set:
- `Spec` and `ADR` URLs for anything this shipped against
- `Notes` — anything a future reader needs that the diff cannot tell them
- `Stage` → `Shipped`

Also set `Status: Shipped` on the spec file itself and append the merge commit SHA, so the spec points at exactly what fulfilled it.

## 8. After deploy

Confirm the health check is green and report it. If a migration ran, confirm it completed on the target. Do not declare shipped based on a merge.
