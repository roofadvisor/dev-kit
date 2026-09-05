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
