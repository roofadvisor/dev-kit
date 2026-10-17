---
name: repo-builder
description: The entry point for starting anything new. Creates the GitHub repo, runs the org and project interview, writes the full scaffold, wires the workflows and Notion sync, makes the first commit, and pushes. Use whenever the user says "new project", "new repo", "start a project", "spin up", "build me a repo", "let's start X", or names something they want to begin. This is the front door — it calls /org-profile, /project-init, and /notion-sync in order so the user never has to invoke them separately.
---

# Repo Builder

One command from "I want to build X" to a pushed repo with rules, hooks, workflows, docs, and a live work queue.

Orchestrates: `/org-profile` → `/project-init` → `/notion-sync` → git → push. Run them in this order; each depends on the last.

---

## 0 — Preflight

```bash
gh auth status
git config user.name && git config user.email
```

If `gh` is not authenticated, stop and tell the user to run `gh auth login`. Do not attempt to authenticate for them.

---

## 1 — Company

Read `~/.claude/f4d/orgs/`. Ask which company this is for.

- **Profile exists** → load it, state the defaults in one line, continue
- **No profile** → run `/org-profile` fully, then continue

Everything downstream inherits: GitHub org, conventions, stack defaults, automation settings, and the constraints block.

---

## 2 — Interview and scaffold

Run `/project-init` in NEW mode. It handles Rounds 0–3 and writes every file. Do not duplicate its questions here.

Wait for it to finish and for the plan table to be approved before touching git.

---

## 3 — Create the repo

Confirm the name and visibility against the org profile's `repo_visibility` before running:

```bash
cd <project-dir>
git init
git branch -M main
gh repo create <github_org>/<repo-slug> --private --source=. --description "<one line>"
```

Use `--public` only if the org profile says public **and** the user confirms in this session. Never make a client repo public.

---

## 4 — Wire automation

Only if the org profile has `claude_github_app: installed`:

```bash
mkdir -p .github/workflows .github/scripts .github/ISSUE_TEMPLATE
cp "$CLAUDE_PLUGIN_ROOT/templates/github/claude.yml"             .github/workflows/
cp "$CLAUDE_PLUGIN_ROOT/templates/github/claude-code-review.yml" .github/workflows/
cp "$CLAUDE_PLUGIN_ROOT/templates/github/bug.yml"                .github/ISSUE_TEMPLATE/
cp "$CLAUDE_PLUGIN_ROOT/templates/github/feature.yml"            .github/ISSUE_TEMPLATE/
```

And if `notion_work_db` is set:

```bash
cp "$CLAUDE_PLUGIN_ROOT/templates/github/notion-sync.yml" .github/workflows/
cp "$CLAUDE_PLUGIN_ROOT/scripts/notion_sync.py"           .github/scripts/
```

Then add the repo to the Work DB's `Repo` select options via `/notion-sync`.

**Secrets and variables are the user's job.** State exactly what they need and where, then move on:

```
Org-level secret:    ANTHROPIC_API_KEY         (preferred: billed per use, no session window)
                or:  CLAUDE_CODE_OAUTH_TOKEN   (fallback: claude setup-token; shares the subscription window)
Org-level secret:    NOTION_TOKEN
Org-level variable:  NOTION_WORK_DB
```

Never run `gh secret set`. Never ask for a token value. Never echo one.

---

## 5 — First commit

```bash
git add -A
git commit -m "chore: scaffold via dev-kit v<version>"
git push -u origin main
```

---

## 6 — Prove it

```bash
./scripts/dev-reset.sh
<verify command>
gh run list --limit 5
```

The scaffold must pass verify before you report success. If it fails, fix the scaffold — never loosen the check.

If Notion sync is wired, open a throwaway issue, confirm a row lands in Triage, then close the issue and delete the row.

---

## 7 — Report

```
REPO:     github.com/<org>/<slug>            (private)
STACK:    <stack>
MODULES:  <rules modules written>
DOCS:     docs/specs, docs/decisions, docs/log.md
CI:       verify · claude · claude-code-review · notion-sync
VERIFY:   PASS
WORK DB:  <linked | not configured>

YOURS TO DO
  1. Add org secrets: ANTHROPIC_API_KEY (or CLAUDE_CODE_OAUTH_TOKEN), NOTION_TOKEN
  2. Add org variable: NOTION_WORK_DB
  3. Share the Work DB with the Notion integration
```

Then stop. Do not start building features. The next move is `/work-intake` on whatever comes first.

---

## Retrofitting an existing repo

If the directory already has code or a remote, do not use this skill. Run `/project-audit` first, then `/project-init` in RETROFIT mode. This skill creates repos; it does not adopt them.
