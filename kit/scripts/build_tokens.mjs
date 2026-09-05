#!/usr/bin/env node
/**
 * TOKEN BUILD — a real, working reference implementation of workflows/token-build.md.
 * Reads the DTCG tokens in tokens/*.json (source of truth), resolves every alias
 * (incl. cross-file {../colors.*} and the dark override map), and emits a single
 * CSS-variable theme: `:root { … }` + `:root[data-theme="dark"] { … }`.
 *
 * Scope: the colour system (semantic + component + dark) PLUS the rest of the system -
 * type, space, radius, shadow, motion, size - under the names the kit's components and
 * rules already use (--text-sm, --space-4, --radius-card, --duration-fast, --ease-out).
 * A colours-only theme leaves every var(--space-*) undefined on a project's first screen.
 *
 * Usage:
 *   node scripts/build_tokens.mjs                                   # prints CSS to stdout
 *   node scripts/build_tokens.mjs --out dist/tokens.css
 *   node scripts/build_tokens.mjs --in design-tokens.json --out src/theme.css
 *
 * --in takes a directory of DTCG files (default: tokens/) or a single self-contained
 * file, which is what a product repo scaffolded by project-init's design bundle has
 * (design-tokens.json at the project root — see skills/project-init/SKILL.md Step 3.7a).
 */
import { readFileSync, readdirSync, statSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';

const ROOT = resolve(dirname(new URL(import.meta.url).pathname), '..');
const arg = (name) => (process.argv.find(a => a.startsWith(`--${name}=`)) || '').split('=')[1]
  || (process.argv.includes(`--${name}`) ? process.argv[process.argv.indexOf(`--${name}`) + 1] : null);
const out = arg('out');
const IN = resolve(arg('in') || join(ROOT, 'tokens'));
const SINGLE = statSync(IN).isFile();
const TOKENS = SINGLE ? dirname(IN) : IN;

// 1) load every token file into a global path->value map (file-namespaced + bare)
const all = {};
// Every leaf, in BOTH addressing forms, so step 5 can prove each one reached the output.
// A group is claimed either bare (`font.size`, single-file layout) or stem-namespaced
// (`typography.fontSize`, directory layout) depending on which candidate path resolved, so a
// leaf has to be checked against both or every directory-layout token reads as unmapped.
const leaves = [];
const SOURCES = SINGLE ? [IN.split('/').pop()] : readdirSync(TOKENS).filter(n => n.endsWith('.json'));
for (const f of SOURCES) {
  const data = JSON.parse(readFileSync(join(TOKENS, f)));
  const stem = f.replace(/\.json$/, '');
  (function walk(o, p) {
    if (o && typeof o === 'object') {
      if ('$value' in o) { all[p] = o.$value; all[`${stem}.${p}`] = o.$value; leaves.push({ bare: p, full: `${stem}.${p}` }); }
      for (const k of Object.keys(o)) if (!k.startsWith('$')) walk(o[k], p ? `${p}.${k}` : k);
    }
  })(data, '');
}

// 2) resolve a value (follow {ref} chains incl. ../ and file prefixes).
// `dark` re-resolves semantic refs through the dark override map, so a COMPONENT
// token that aliases into the semantic tier gets its dark value instead of keeping
// the light one. Without this a `button.secondary-text` pinned to the light ink
// ships dark-on-dark: found by a blind eval run at 1.13:1.
function res(v, depth = 0, dark = null) {
  if (depth > 16 || typeof v !== 'string') return v;
  const m = v.match(/^\{(.+)\}$/);
  if (!m) return v;
  let ref = m[1].trim();
  while (ref.startsWith('../') || ref.startsWith('./')) ref = ref.startsWith('../') ? ref.slice(3) : ref.slice(2);
  let val;
  if (dark) {
    const bare = ref.replace(/^(colors\.)?semantic\./, '');
    val = dark[bare] ?? dark[ref];
  }
  if (val === undefined) val = all[ref];
  if (val === undefined) { const tail = ref.split('.').slice(1).join('.'); val = all[ref] ?? all[tail]; }
  return val === undefined ? v : res(val, depth + 1, dark);
}

// 3) emit semantic + component color tokens as --color-* ; dark section as overrides
const colors = JSON.parse(readFileSync(SINGLE ? IN : join(TOKENS, 'colors.json')));
const lines = { light: [], dark: [] };
function emit(obj, prefix, bucket, dark = null) {
  for (const [k, v] of Object.entries(obj || {})) {
    if (k.startsWith('$')) continue;
    if (v && typeof v === 'object' && '$value' in v) {
      const hex = res(v.$value, 0, dark);
      if (typeof hex === 'string' && /^(#|rgb|hsl)/.test(hex)) lines[bucket].push(`  --color-${prefix}${k}: ${hex};`);
    } else if (v && typeof v === 'object') {
      emit(v, `${prefix}${k}-`, bucket, dark);
    }
  }
}

// flatten the dark override map once: "text.primary" -> "{primitive.gray.50}"
function flattenDark(obj, prefix = '', out = {}) {
  for (const [k, v] of Object.entries(obj || {})) {
    if (k.startsWith('$')) continue;
    if (v && typeof v === 'object' && '$value' in v) out[`${prefix}${k}`] = v.$value;
    else if (v && typeof v === 'object') flattenDark(v, `${prefix}${k}.`, out);
  }
  return out;
}
emit(colors.semantic, '', 'light');
if (colors.component) emit(colors.component, '', 'light');
if (colors.dark) {
  const darkMap = flattenDark(colors.dark);
  emit(colors.dark, '', 'dark');
  // the component tier follows the semantic swap into dark, or it stays light
  if (colors.component) emit(colors.component, '', 'dark', darkMap);
}

/* 4) the rest of the system. Colour alone is not a theme: a project scaffolded from
   the template writes var(--space-4) and var(--text-sm) on its first screen, and a
   colours-only build leaves every one of those undefined. Two blind eval runs hit
   this within minutes of starting. Groups map to the names the kit's own components
   and rules use. */
// Each group lists candidate paths: the single-file template layout first (font.size),
// then where the group actually lives across tokens/*.json in directory mode
// (typography.fontSize) — a colors-only lookup finds neither.
const GROUPS = [
  [['font.family', 'typography.fontFamily'], 'font-'],
  [['font.size', 'typography.fontSize'], 'text-'],
  [['font.weight', 'typography.fontWeight'], 'weight-'],
  [['font.leading', 'typography.lineHeight'], 'leading-'],
  [['typography.textStyle'], 'text-'], // composite styles: the adapters declare `font: var(--text-label)`
  [['space', 'spacing.scale'], 'space-'],
  [['spacing.semantic'], 'space-'],                 // page/card/stack/inline/component — 30 tokens B1 had hidden
  [['radius', 'borders.radius'], 'radius-'],
  [['borders.width'], 'border-width-'],
  [['borders.style'], 'border-'],                  // composite -> the `border` shorthand
  [['gradients.brand'], 'gradient-'],
  [['gradients.surface'], 'gradient-surface-'],
  [['gradients.accent'], 'gradient-accent-'],
  [['gradients.feedback'], 'gradient-'],
  [['typography.letterSpacing'], 'tracking-'],
  [['states'], 'state-'],
  [['radius-semantic', 'borders.radius-semantic'], 'radius-'],
  [['shadow', 'shadows.elevation'], 'shadow-'],
  [['shadows.inner'], 'shadow-inner-'],
  [['shadows.colored'], 'shadow-colored-'],
  [['shadows.focus-ring'], 'shadow-focus-ring'],
  [['shadows.elevation.2xl'], 'shadow-overlay'], // the golden Modal consumes this exact name
  [['motion.duration'], 'duration-'],
  [['motion.easing'], 'ease-'],
  [['motion.transition'], 'transition-'],
  [['size', 'sizing'], 'size-'],
  [['opacity'], 'opacity-'],
  [['blur'], 'blur-'],
  [['z', 'breakpoints.z-index'], 'z-'],
  [['data-viz.categorical'], 'color-chart-'],
  [['data-viz.sequential'], 'color-chart-seq-'],   // ordered/continuous ramp
  [['data-viz.diverging'], 'color-chart-div-'],    // two-ended ramp
  [['data-viz.semantic'], 'color-chart-'],
  [['data-viz.axis'], 'color-chart-axis-'],
  [['data-viz.surface'], 'color-chart-'],
  // the harnesses consume these two exact names; their sources are the grid-line pair
  [['data-viz.grid.line'], 'color-chart-grid'],
  [['data-viz.grid.line-subtle'], 'color-chart-track'],
  [['breakpoints.breakpoint'], 'bp-'], // the golden modal + sample app consume --bp-sm/--bp-lg
  [['breakpoints.container'], 'container-'],
  [['breakpoints.grid'], 'grid-'],
  [['breakpoints.sidebar'], 'sidebar-'],
];
// Lookup view spanning EVERY source file: namespaced by file stem, top-level keys also
// merged bare (first file wins), so both layouts resolve.
const system = {};
for (const f of SOURCES) {
  const data = JSON.parse(readFileSync(join(TOKENS, f)));
  const stem = f.replace(/\.json$/, '');
  if (!(stem in system)) system[stem] = data;
  for (const [k, v] of Object.entries(data)) if (!k.startsWith('$') && !(k in system)) system[k] = v;
}
const lookup = (path) => path.split('.').reduce((o, k) => (o && typeof o === 'object' ? o[k] : undefined), system);
const at = (paths) => {
  for (const p of Array.isArray(paths) ? paths : [paths]) { const n = lookup(p); if (n) return n; }
  return undefined;
};

// one DTCG shadow layer object -> CSS; color may be an alias
function shadowLayer(o, dark = null) {
  if (!o || typeof o !== 'object') return null;
  const p = (x, fallback) => {
    if (x === undefined) return fallback;
    const r = res(x, 0, dark);
    return typeof r === 'string' || typeof r === 'number' ? r : x;
  };
  return `${o.inset ? 'inset ' : ''}${p(o.offsetX, '0')} ${p(o.offsetY, '0')} ${p(o.blur, '0')} ${p(o.spread, '0')} ${p(o.color, 'currentColor')}`;
}

function cssValue(v, dark = null) {
  if (Array.isArray(v)) {
    // DTCG uses arrays for three types; dispatch on element type, not blindly cubicBezier
    if (typeof v[0] === 'number') return `cubic-bezier(${v.join(', ')})`;
    if (typeof v[0] === 'string') return v.map(n => /\s/.test(n) ? `"${n}"` : n).join(', '); // fontFamily stack
    if (typeof v[0] === 'object') {
      // DTCG gradient stops carry `position`; shadow layers never do. Without this the stop
      // objects fell through to shadowLayer, produced nothing, and every gradient token was
      // dropped in silence — which step 5 now reports rather than hides.
      if ('position' in v[0]) {
        const stops = v.map(st => {
          const c = res(st.color, 0, dark);
          const col = typeof c === 'string' ? c : st.color;
          return `${col} ${Math.round(Number(st.position) * 100)}%`;
        });
        // No direction is encoded in the token, so no direction is invented here: bare stops
        // use CSS's own default (to bottom).
        return `linear-gradient(${stops.join(', ')})`;
      }
      const layers = v.map(o => shadowLayer(o, dark)).filter(Boolean);
      return layers.length ? layers.join(', ') : null;
    }
    return null;
  }
  if (typeof v === 'number') return String(v);
  if (v && typeof v === 'object') {
    // DTCG typography object -> CSS font shorthand "weight size/line-height family"
    // (letterSpacing cannot ride the shorthand and is dropped here)
    if ('fontSize' in v || 'fontFamily' in v) {
      const part = (x) => { const r = res(x, 0, dark); return cssValue(r, dark) ?? (typeof r === 'string' || typeof r === 'number' ? String(r) : null); };
      const size = part(v.fontSize), fam = part(v.fontFamily);
      if (!size || !fam) return null;
      const weight = part(v.fontWeight), lh = part(v.lineHeight);
      return `${weight ? weight + ' ' : ''}${size}${lh ? '/' + lh : ''} ${fam}`;
    }
    // DTCG transition object -> "duration timing-function delay"
    if ('duration' in v || 'timingFunction' in v) {
      const part = (x) => { const r = res(x, 0, dark); return cssValue(r, dark) ?? (typeof r === 'string' ? r : null); };
      const dur = part(v.duration ?? '0ms'), tf = part(v.timingFunction ?? 'ease'), delay = part(v.delay ?? '0ms');
      return dur && tf ? `${dur} ${tf}${delay && delay !== '0ms' ? ' ' + delay : ''}` : null;
    }
    // DTCG border composite -> the CSS shorthand
    if ('style' in v && ('width' in v || 'color' in v)) {
      const part = (x) => { const r = res(x, 0, dark); return typeof r === 'string' || typeof r === 'number' ? String(r) : null; };
      const w = part(v.width), st = part(v.style), c = part(v.color);
      return [w, st, c].filter(Boolean).join(' ') || null;
    }
    return shadowLayer(v, dark); // single shadow object
  }
  if (typeof v !== 'string') return null;
  // a shadow or gradient can carry {refs} inside a longer string
  return v.replace(/\{([^}]+)\}/g, (_, ref) => {
    const out = res(`{${ref}}`, 0, dark);
    return typeof out === 'string' ? out : `{${ref}}`;
  });
}

function emitGroup(node, prefix, bucket, dark = null) {
  for (const [k, v] of Object.entries(node || {})) {
    if (k.startsWith('$')) continue;
    let ck = k.replace(/\./g, '-'); // "0.5" -> "0-5": a bare dot is invalid in a custom-property name
    // easing keys already carry "ease-": collapse --ease-ease-out to the consumed --ease-out
    if (prefix === 'ease-' && ck.startsWith('ease-')) ck = ck.slice(5);
    if (v && typeof v === 'object' && '$value' in v) {
      const out = cssValue(v.$value, dark);
      if (out !== null && !/\{[^}]+\}/.test(String(out))) lines[bucket].push(`  --${prefix}${ck}: ${out};`);
    } else if (v && typeof v === 'object') {
      emitGroup(v, `${prefix}${ck}-`, bucket, dark);
    }
  }
}

// Colour tiers are claimed by the FILE that carries them — `colors` in a directory, the file
// itself in single-file mode — and matched on a leaf's full path only (below). 2.1.0 claimed
// them bare, so a top-level `semantic` in any file read as covered: spacing.json's 30 semantic
// tokens were hidden from the report that way (2.2.0, B1).
const colourStem = (SINGLE ? SOURCES[0] : 'colors.json').replace(/\.json$/, '');
const colourClaims = ['primitive', 'semantic', 'component', 'dark'].map(t => `${colourStem}.${t}`);
const claimed = [];
for (const [paths, prefix] of GROUPS) {
  const node = at(paths);
  if (!node) continue;
  claimed.push(...(Array.isArray(paths) ? paths : [paths]).filter(p => lookup(p)));
  if (typeof node === 'object' && '$value' in node) {
    // a leaf group entry (e.g. shadows.focus-ring) emits one var named by its prefix
    const out = cssValue(node.$value);
    if (out !== null && !/\{[^}]+\}/.test(String(out))) lines.light.push(`  --${prefix.replace(/-$/, '')}: ${out};`);
  } else {
    emitGroup(node, prefix, 'light');
  }
}
// a shadow that references a surface (the focus ring's gap colour) has to follow dark
const shadowNode = at(['shadow', 'shadows.elevation']);
if (colors.dark && shadowNode) emitGroup(shadowNode, 'shadow-', 'dark', flattenDark(colors.dark));

/* 5) Prove every token reached the output.

   A group this builder does not recognise is otherwise dropped in silence. roof-club's base,
   product and operator systems each declared `font.line-height` where the builder reads
   `font.leading`, so every line-height vanished from every build for weeks — no error, and
   nothing conspicuously absent from the CSS to notice. A token you wrote and cannot use is
   worse than one you never wrote, because you believe it is live.

   Warns by default so an upgrade cannot break an existing build; `--strict` makes it fatal,
   which is what a project's own token gate should use. */
const STRICT = process.argv.includes('--strict');
/* Groups that are real tokens but genuinely cannot be a custom property. Listed explicitly, with
   the reason, rather than left to warn: a check that cries wolf gets ignored, and then it is
   worth nothing on the day it is right. Anything NOT here and NOT in GROUPS is a bug. */
const NOT_EMITTED = [
  ['motion.keyframes', 'composite from/to recipes — encode as CSS @keyframes'],
  ['motion.reducedMotion', 'a prefers-reduced-motion media-query concern, not a value'],
  ['theming', 'theme and density sets are applied by selection, not flattened into :root'],
];
const covers = (path) => claimed.some(c => path === c || path.startsWith(`${c}.`));
const colourCovered = (full) => colourClaims.some(c => full === c || full.startsWith(`${c}.`));
const excused = (path) => NOT_EMITTED.some(([c]) => path === c || path.startsWith(`${c}.`));
const unmapped = leaves.filter(
  (l) => !covers(l.bare) && !covers(l.full) && !colourCovered(l.full) && !excused(l.bare) && !excused(l.full)
);
if (unmapped.length) {
  // Report the containing group, not every leaf under it: one line saying `font.line-height
  // (2 tokens)` beats twenty saying `font.line-height.tight`.
  const byGroup = new Map();
  for (const l of unmapped) {
    const parts = l.full.split('.');
    const key = parts.length > 1 ? parts.slice(0, -1).join('.') : l.full;
    const g = byGroup.get(key) || { n: 0, root: l.bare.split('.')[0] };
    g.n += 1;
    byGroup.set(key, g);
  }
  // Every path this builder knows, for the near-miss suggestion.
  const known = GROUPS.flatMap(([paths]) => paths);
  const w = STRICT ? 'ERROR' : 'WARNING';
  console.error(`\n${w}: ${unmapped.length} token(s) produced no CSS variable — nothing consumes them:`);
  for (const [g, { n, root }] of [...byGroup].sort()) {
    console.error(`  ${g}  (${n} token${n === 1 ? '' : 's'})`);
    // A wrong key is nearly always a near miss, so name the siblings under the same root.
    const near = known.filter(k => k.split('.')[0] === root);
    if (near.length) console.error(`      this builder reads: ${near.join(', ')}`);
  }
  console.error('  Rename the group to one the builder reads, or delete it. Suppress with neither.\n');
  if (STRICT) process.exit(1);
}

const css = `/* Generated by scripts/build_tokens.mjs from ${SINGLE ? arg('in') : 'tokens/*.json'} — do not edit by hand. */
:root {
${[...new Set(lines.light)].join('\n')}
}
:root[data-theme="dark"] {
${[...new Set(lines.dark)].join('\n')}
}
`;

if (out) {
  mkdirSync(dirname(resolve(out)), { recursive: true });
  writeFileSync(resolve(out), css);
  console.log(`wrote ${[...new Set(lines.light)].length} light + ${[...new Set(lines.dark)].length} dark color vars → ${out}`);
} else {
  process.stdout.write(css);
}
