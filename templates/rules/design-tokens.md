---
id: design-tokens
always_apply: false
---
# Design tokens

Loaded when you are touching `design-tokens.json` or a theme file.

## The three tiers

```
component   button-bg-primary  ->  {semantic.action.primary}    used in components
semantic    action.primary     ->  {primitive.brand.600}        used in design
primitive   brand.600          ->  #2563eb                      never used directly
```

A component never reads a primitive. If a component needs a colour that has no
semantic name yet, the missing thing is the semantic name, not permission to
reach one tier down.

## Adding a token

1. Does a semantic token already mean this? Use it. Two names for one meaning is
   how a design system dies.
2. Name it for purpose, not appearance: `feedback.error-text`, not `red-dark`.
   The shape is `{category}.{property}.{variant}-{state}`.
3. Add the light value and the dark value together. A token that exists in only
   one theme will ship broken in the other.
4. DTCG format, always `$type` and `$value`, alias with `{dotted.path}`.

## Changing a token

Change it here, in one place, and let every screen follow. If a screen needs a
different value, that is a new semantic token or a theme override, never a local
hex.

## Dark mode

Primitives do not change between themes. The swap happens at the semantic tier
via `[data-theme="dark"]`. Light surfaces carry dark text and dark surfaces carry
light text, and both have to pass contrast before the change counts as made.

## Type scale

Major Third ratio (1.25):

```
xs=12  sm=14  base=16  lg=18  xl=20  2xl=24  3xl=30  4xl=36  5xl=48  6xl=60  7xl=72
```

1. **One font family for UI** — Inter (or system-ui) for all interface text.
2. **Serif for editorial** — Lora (or Georgia) for blog posts, marketing pages.
3. **Mono for code** — JetBrains Mono for code blocks, data values.
4. **Heading hierarchy** — h1 is used once per page; headings never skip levels.
5. **Line length** — body text: 45–75 characters per line (65ch optimal). Use
   `max-width: 65ch`.
6. **Line height** — headings: tight (1.25). Body: normal (1.5). Caption: normal
   (1.5).
7. **Font weight** — regular (400) for body, medium (500) for labels, semibold
   (600) for headings, bold (700) for page titles only.

These live as composite text styles inside `design-tokens.json`, not as raw
per-element values.

## Spacing

Base unit 4px. Every spacing value is a multiple of it:

```
0  2  4  6  8  10  12  14  16  20  24  28  32  36  40  44  48  56  64  80  96
```

1. **Outer spacing > inner spacing** — container padding > element gaps >
   element padding.
2. **Related items closer** — related elements share tighter spacing than
   unrelated ones.
3. **Consistent rhythm** — establish a vertical rhythm and maintain it
   throughout the page.
4. **Semantic spacing** — use purpose-named tokens (`card.padding`, `stack.lg`)
   over raw values.

The full scale and its semantic aliases live in `design-tokens.json`, alongside
every other tier.

## Motion

1. **Duration** — 100–300ms for UI transitions. Never > 500ms.
2. **Easing** — `ease-out` for entrances, `ease-in` for exits, `ease-in-out` for
   state changes.
3. **Purpose** — every animation guides attention, shows connection, or
   provides feedback.
4. **Reduced motion** — always respect `prefers-reduced-motion`. Replace with
   fade or instant.
5. **Tokenized** — all motion values (duration scale, easing curves, transition
   presets, keyframes) come from `design-tokens.json`. Never hardcode timing or
   easing.

## Color guidelines

### Contrast

| Element | Minimum ratio |
|---|---|
| Normal text (< 24px) | 4.5:1 |
| Large text (≥ 24px, or ≥ 18.66px bold) | 3:1 |
| UI components and graphical objects | 3:1 (a purely decorative border/divider is exempt) |
| Focus indicators | 3:1 |

### Color usage

1. **Never color-only** — pair every color-coded signal with an icon, text, or
   pattern.
2. **Feedback colors** — success (green), warning (amber), error (red), info
   (blue).
3. **Interactive colors** — every clickable element uses `action.primary` or
   `text.link`.
4. **Limit the palette** — one primary, one destructive, neutrals. Accent
   colors are used sparingly.
5. **Token BY INTENT (non-negotiable)** — pick the token whose *meaning*
   matches the action, not just any token that resolves to the right pixels:
   - Destructive actions (Delete, Remove, Revoke) use `action.destructive` /
     `component.button.destructive-bg` — never `action.primary`. The same
     destructive action wears the same danger variant everywhere (the trigger
     button and its confirm-modal button never disagree).
   - Primary = the one main affirmative action. Secondary = neutral
     (transparent/outline, dark text — never a colored fill). Danger =
     destructive.
   - One action role, one variant, across every page. A blue "Delete" is a bug.
6. **No emoji, anywhere** — not just as icons. Never as an icon, bullet,
   status dot, rating face, section marker, or decoration, in UI, code, JSON,
   copy, comments, or commit messages. Use a real icon set (lucide) as inline
   SVG with `currentColor`, or plain words. Enforced by
   `python3 "${CLAUDE_PLUGIN_ROOT}/kit/scripts/check_no_emoji.py"`.

### Color generation

New palette, new brand hue? Use OKLCH for perceptually uniform shade scales:

1. Define the brand hue (e.g. hue = 264 for purple).
2. Generate 11 shades from L=97% (50) to L=15% (950) with consistent chroma.
3. Verify the 500 shade meets 4.5:1 contrast on white for text use.
4. Verify the 600 shade meets 3:1 contrast on white for UI use.

### Single-theme consistency

Every page, screen, and component in a project renders from **one shared
token theme** — never a per-page palette or ad-hoc colors. This is what keeps
a 50-screen product visually identical and themeable from one place.

1. **One source of truth** — `design-tokens.json` → a single CSS-variable
   layer (`:root` + `[data-theme="dark"]`) imported once at the app root.
   Every page references the same semantic tokens; none redefines colors.
2. **No off-theme values** — zero hardcoded hex/px/timing in component or
   page code. Enforced by `lint_hardcodes.py` (the one allowed exception:
   adapter theme-config that maps our tokens *into* a 3rd-party API, e.g.
   MUI/Mantine).
3. **Real WCAG, on the source** — the token theme itself passes WCAG 2.2 in
   both light and dark before any page ships. Enforced by
   `validate_contrast.py`.
4. **One gate runs all of it** — the project's own `verify` runs
   `validate_tokens`, `validate_contrast`, `build_tokens --strict` and
   `lint_hardcodes` from `node_modules/@roofadvisor/dev-kit/kit`
   (project-init step 7a), so nothing merges on drift. `/gate` is the
   plugin's self-check; it never tests a project.

Switching brand or theme means editing the token source once and letting
every page update. If a page "looks different," it bypassed the theme — that
is a bug, not a variant.

## After any edit

```
python3 "${CLAUDE_PLUGIN_ROOT}/kit/scripts/validate_tokens.py"     design-tokens.json          aliases resolve, JSON parses
python3 "${CLAUDE_PLUGIN_ROOT}/kit/scripts/validate_contrast.py"   design-tokens.json          WCAG on the source, light and dark
node    "${CLAUDE_PLUGIN_ROOT}/kit/scripts/build_tokens.mjs"       --in design-tokens.json --out src/theme.css
python3 "${CLAUDE_PLUGIN_ROOT}/kit/scripts/validate_theme_refs.py" src/theme.css src           every var(--...) resolves
python3 "${CLAUDE_PLUGIN_ROOT}/kit/scripts/lint_hardcodes.py"      src                          nothing bypassed the theme
```

Or run all of them plus the render gates with `/gate`.

Report the real output. A contrast ratio you did not measure is not a number, it
is a guess.
