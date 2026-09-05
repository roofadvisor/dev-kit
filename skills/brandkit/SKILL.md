---
name: brandkit
description: Generate a complete, accessible brand design system from a brief — primitive → semantic → component DTCG tokens (color, type, spacing, radius, shadow, motion), light + dark, plus a single theme.css — verified for WCAG. Use when the user wants a from-scratch brand/design foundation, a new palette + type system, or a themeable token kit for a product.
invocation: user
adapted: "Roof Club 2026-08-31 - vendored from plugin87/ux-ui-agent-skills; kit paths rewritten to ${CLAUDE_PLUGIN_ROOT}/kit/ (see ${CLAUDE_PLUGIN_ROOT}/PROVENANCE.md)"
---

# Skill: Brand Kit

Stand up the *foundation* (one token system everything renders from) before any screen. Get this right and every page stays consistent and themeable from one place.

## Steps
1. **Brief Inference (mandatory)** — name the industry, audience, the one mood adjective, and motion depth (`${CLAUDE_PLUGIN_ROOT}/kit/taste/design-taste.md` → Brief Inference). Pick an anchoring archetype from `${CLAUDE_PLUGIN_ROOT}/kit/taste/aesthetic-systems.md`.
2. **Primitives** — generate the brand color ramp in **OKLCH** (11 shades, consistent chroma) + a neutral ramp; verify the 500 shade ≥ 4.5:1 on white (text) and 600 ≥ 3:1 (UI) per `${CLAUDE_PLUGIN_ROOT}/templates/rules/design-tokens.md` → Color guidelines § Color generation.
3. **Semantic layer** — map roles to primitives: `action.primary`/`-hover`/`destructive`, `text.{primary,secondary,on-action,link}`, `surface.{page,card,raised}`, `border.{default,strong}`, `feedback.{success,warning,error,info}` — and the **dark** overrides (designed, not inverted).
4. **Scales** — Major Third type scale + composite text styles, 4px spacing scale, radius tiers, elevation, and `${CLAUDE_PLUGIN_ROOT}/kit/tokens/motion.json`-style durations/easings.
5. **Emit** the DTCG `${CLAUDE_PLUGIN_ROOT}/kit/tokens/*.json` (3-tier) + a single `theme.css` (the one shared source, `[data-theme="dark"]` overrides). Optionally feed the token-build pipeline (`token-build` skill) for other platforms.

## Verification (definition of done)
- `python3 ${CLAUDE_PLUGIN_ROOT}/kit/scripts/validate_tokens.py` — valid JSON, all aliases resolve.
- `python3 ${CLAUDE_PLUGIN_ROOT}/kit/scripts/validate_contrast.py` — required text/action/border pairs pass WCAG AA in **light AND dark**; `border.strong` ≥ 3:1.
- `python3 ${CLAUDE_PLUGIN_ROOT}/kit/scripts/validate_theme_refs.py` — every component `var(--…)` resolves to the theme.
- One theme, no per-page palettes; destructive = danger token (not primary); zero hardcoded values.

> Output is a verified token foundation — the measurable part is provable (run the project's own gate — `validate_tokens`, `validate_contrast`, `build_tokens --strict`, `lint_hardcodes` from `node_modules/@roofadvisor/dev-kit/kit`, project-init step 7a; `accuracy_report.mjs` is the plugin's self-check and never tests a project). Brand "feel" still benefits from a human review against `${CLAUDE_PLUGIN_ROOT}/kit/taste/design-taste.md`.
