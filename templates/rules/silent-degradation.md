---
id: silent-degradation
always_apply: true
---
# Silent Degradation

The failure class that survives review: something goes wrong and the output still
looks plausible, so it reads as data rather than as a defect.

## Never degrade to a default

- A new value, type, or shape arriving from an external source must **fail a check**, not fall back.
- An unknown enum value renders visibly blocked. It never silently maps to the first option, "other", or null.
- If a value cannot be resolved, the caller learns that. It does not receive a plausible substitute.

## Alarm on the path that consumes the value

The rule above says the caller learns. It does not say *where*, and putting the alarm where
the value is computed rather than where it is used turns a detector into noise.

- **A non-resolution is only news on a path that needed the value.** Compute a signal for
  every case if that is simplest, but report its absence only where something depended on it.
- **A warning that fires on the healthy path is worse than no warning**, because it teaches
  the reader that this warning means nothing — and it will still be meaningless on the day
  the drift is real. Measured: an editor resolved seven opportunity-only keys on every entity
  and logged seven "not in catalog" lines per open on three of four entity types. Both the
  author and the reviewer learned to scroll past it.
- The question to ask of any new alarm: **on which inputs is this silent?** If the answer is
  "the ones where the value is actually used", the alarm is inverted.

## catch → empty is a trap

- `catch { return [] }` does not merely hide a failure — it **passes every downstream "is anything missing?" check**, because nothing is missing from an empty set.
- When changing error handling on a collection, grep the consumers for *comparisons and counts*, not just renderers. The renderer shows nothing; the gate says everything is fine.
- An empty collection makes an assertion vacuously true. Any test that iterates a collection must first assert the collection is non-empty.

## Guess lists

- A hardcoded list of values that the source could have told you is a silent-degradation machine: when it misses, it returns something plausible.
- **One canonical resolver per question.** Two lists in two places will disagree, and the disagreement surfaces as a blank rather than a conflict.
- Where a module boundary prevents sharing, extract a dependency-free leaf both sides import. Never copy.
- Do not infer what the source already stated. If the API reports a field's type and permitted values, map that vocabulary directly. Inference is a fallback for when the source is silent — never an override.

## The hardcode boundary

- **Account/tenant data** — what a given account contains — must be read live. Never hardcoded.
- **Contract data** — endpoint shapes, enum spellings, required echoes — may be a labelled, reviewed constant.
- A pure function must not fetch. Resolve live values at the layer that can, and pass the settled value in.

## Numbers

- Cross-check any load-bearing number against a second source. Two selectively-populated fields can fake a passing suite.
- Never render a raw id. Show the hydrated value, and lock it with a test that fails if the id appears.
