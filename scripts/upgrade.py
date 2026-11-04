#!/usr/bin/env python3
"""
A1 — framework upgrade path.

Diffs a project's .claude/ against the plugin's current templates and classifies
every difference. Project customizations must survive; that is what makes this
usable more than once.

  UNCHANGED   identical — nothing to do
  FRAMEWORK   plugin changed, project untouched     → safe to apply
  LOCAL       project customized, plugin unchanged  → keep, never overwrite
  CONFLICT    both changed                          → human decides
  NEW         plugin has a file the project lacks   → offer
  ORPHAN      project has a rule the plugin dropped → flag, do not delete

Default is a dry run. --apply writes only FRAMEWORK and accepted NEW.
"""
import argparse
import hashlib
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _common import repo_root  # noqa: E402

STATE = ".claude/.framework-state.json"
# A18 — this file now does double duty. It has always been the file-sync
# baseline below; since hooks/hooks.json shipped, its mere PRESENCE is also
# what hook_opted_in() (hooks/_parse.sh) checks to decide whether this repo's
# plugin-declared hooks (guard.sh, rule-zero.sh, done-check.sh,
# verify-record.sh, session-context.sh) do anything at all.
#
# No migration or backfill was needed for that: every repo /project-init has
# ever taken through step 7 (companions) or step 11 (this module's --apply)
# already has this file, on every version of the kit, including every one
# scaffolded before A18 was fixed. The moment such a repo's plugin installation
# updates past the version that ships hooks/hooks.json, its hooks start firing
# for real — with ZERO changes required in the target repo itself. Presence
# alone is deliberately the whole opt-in signal; hook_opted_in() never parses
# this file's contents (see its own comment for why a malformed-but-present
# file must still count as opted in), so nothing here needs a new field for
# A18 and nothing below needs to change to keep writing it correctly.


def digest(path):
    if not os.path.exists(path):
        return None
    return hashlib.sha256(open(path, "rb").read()).hexdigest()[:16]


def load_state(base):
    p = os.path.join(base, STATE)
    state = json.load(open(p)) if os.path.exists(p) else {}
    state.setdefault("version", None)
    state.setdefault("files", {})
    # C1: repos scaffolded before the design-bundle interview question shipped
    # have no "bundles" key at all. Absent means [] here, never a KeyError in
    # this script or in a caller (project-audit) that reads state["bundles"]
    # expecting a list it can iterate. Symmetric with save_state below, which
    # already round-trips this key once it exists — the only gap was the read
    # side crashing (or a caller crashing) on a file written before it did.
    state.setdefault("bundles", [])
    return state


def save_state(base, version, files, registry_ids=None, companions=None):
    p = os.path.join(base, STATE)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    # C1 taught that a partial state file (e.g. the scaffold's step 7, before
    # step 11 has ever run) must not crash a reader. The symmetric write-side
    # risk is silent data loss: enumerating known keys and dropping everything
    # else closes ONE instance of "upgrade destroys a declaration it did not
    # author" (companions, previously). Starting the payload from the existing
    # state's UNKNOWN keys instead closes the whole class — any future key
    # added to .framework-state.json survives an upgrade even if save_state is
    # never taught its name.
    known = ("version", "files", "registry_ids", "companions")
    payload = {k: v for k, v in load_state(base).items() if k not in known}
    payload["version"] = version
    payload["files"] = files
    if registry_ids is not None:
        payload["registry_ids"] = sorted(registry_ids)
    # Symmetric with registry_ids above: check presence, not truthiness, so an
    # explicit {} (a real, deliberate "no companions" state) is not silently
    # dropped the way a truthy-only check (`if companions:`) would drop it.
    if companions is not None:
        payload["companions"] = companions
    json.dump(payload, open(p, "w"), indent=2, sort_keys=True)


def plugin_version(plugin):
    p = os.path.join(plugin, ".claude-plugin", "plugin.json")
    return json.load(open(p))["version"] if os.path.exists(p) else "unknown"


def classify(base, plugin, state):
    """Compare each managed file three ways: as-shipped-before, now-in-project, now-in-plugin."""
    rows = []
    src_root = os.path.join(plugin, "templates", "rules")
    dst_root = os.path.join(base, ".claude", "rules")

    plugin_files = set(os.listdir(src_root)) if os.path.isdir(src_root) else set()
    project_files = set(os.listdir(dst_root)) if os.path.isdir(dst_root) else set()

    for name in sorted(plugin_files | project_files):
        if not name.endswith(".md"):
            continue
        if name == "REGISTRY.md":
            # A2: the registry lives in the plugin only; projects hold a manifest
            # and render their view. A committed copy is drift, not a NEW offer.
            if name in project_files:
                rows.append(("STALE-REGISTRY", f".claude/rules/{name}",
                             "projects render from manifest.json now (A2) — this copy will drift; migrate and remove"))
            continue
        rel = f".claude/rules/{name}"
        baseline = state["files"].get(rel)
        proj = digest(os.path.join(dst_root, name))
        plug = digest(os.path.join(src_root, name))

        if proj is None:
            rows.append(("NEW", rel, "plugin has it, project does not"))
        elif plug is None:
            rows.append(("ORPHAN", rel, "plugin dropped it; project still holds it"))
        elif proj == plug:
            rows.append(("UNCHANGED", rel, ""))
        elif baseline is None:
            rows.append(("CONFLICT", rel, "no baseline recorded — cannot tell who changed it"))
        elif proj == baseline and plug != baseline:
            rows.append(("FRAMEWORK", rel, "plugin changed, project untouched"))
        elif proj != baseline and plug == baseline:
            rows.append(("LOCAL", rel, "project customized — will not overwrite"))
        else:
            rows.append(("CONFLICT", rel, "both changed since last sync"))
    return rows


def manifest_report(base, plugin, state):
    """A2 step 5 — reconcile the project's rule manifest against the plugin registry.

    Uses the SAME complete validation as render_registry --validate (a manifest
    the audit rejects must never pass an upgrade). NEW candidates are rules
    added to the plugin registry SINCE THE RECORDED BASELINE — not every unheld
    rule, which would report the same dozens forever. Returns the problem list
    so the caller can fail the run.
    """
    mpath = os.path.join(base, ".claude", "rules", "manifest.json")
    if not os.path.exists(mpath):
        return []
    from render_registry import load_manifest, manifest_problems, parse_registry  # single source (S-05)
    rules, overrides = load_manifest(mpath)
    _, by_id = parse_registry(os.path.join(plugin, "templates", "rules", "REGISTRY.md"))
    problems = manifest_problems(rules, overrides, by_id)
    print()
    print(f"registry manifest   {len(rules)} rules held, {len(overrides)} override(s)")
    for p in problems:
        print(f"  BROKEN     {p}")
    if problems:
        print("             Fix the manifest before anything else (A9: IDs are permanent).")

    baseline_ids = state.get("registry_ids")
    if baseline_ids is None:
        unheld = sorted(set(by_id) - set(rules))
        print(f"  NOTE       no registry baseline recorded yet — cannot tell new rules from")
        print(f"             deliberately-unheld ones ({len(unheld)} unheld total). --apply records the baseline.")
    else:
        new = sorted(set(by_id) - set(baseline_ids))
        if new:
            print(f"  NEW rules  added to the plugin registry since the recorded baseline: {', '.join(new)}")
            print("             Review each against this project — adoption is a decision, not a sync.")
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plugin", required=True, help="path to the dev-kit plugin")
    ap.add_argument("--apply", action="store_true", help="write FRAMEWORK and NEW changes")
    ap.add_argument("--accept-new", action="store_true", help="also install NEW files")
    args = ap.parse_args()

    base = repo_root()
    state = load_state(base)
    newver = plugin_version(args.plugin)

    print(f"project  {base}")
    print(f"pinned   {state['version'] or '(never synced)'}")
    print(f"plugin   {newver}")
    print()

    rows = classify(base, args.plugin, state)
    counts = {}
    for kind, rel, why in rows:
        counts[kind] = counts.get(kind, 0) + 1
        if kind == "UNCHANGED":
            continue
        print(f"  {kind:<10} {rel}")
        if why:
            print(f"             {why}")

    print()
    print("  ".join(f"{k}={v}" for k, v in sorted(counts.items())))

    broken_refs = manifest_report(base, args.plugin, state)

    if counts.get("CONFLICT"):
        print()
        print("CONFLICTS need a human. For each, decide whether the local change is")
        print("still wanted, then re-run. Never resolve a conflict by taking the")
        print("framework wholesale — that silently deletes a project-specific rule")
        print("someone added for a reason.")

    if not args.apply:
        print()
        print("Dry run. Re-run with --apply to write FRAMEWORK changes.")
        return 1 if broken_refs else 0

    written = []
    for kind, rel, _ in rows:
        if kind == "FRAMEWORK" or (kind == "NEW" and args.accept_new):
            src = os.path.join(args.plugin, "templates", "rules", os.path.basename(rel))
            dst = os.path.join(base, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst)
            written.append(rel)

    files = dict(state["files"])
    for kind, rel, _ in rows:
        if kind in ("UNCHANGED", "FRAMEWORK", "NEW", "LOCAL"):
            d = digest(os.path.join(base, rel))
            if d:
                files[rel] = d
    try:
        from render_registry import parse_registry
        _, by_id = parse_registry(os.path.join(args.plugin, "templates", "rules", "REGISTRY.md"))
        registry_ids = list(by_id)
    except SystemExit:
        registry_ids = state.get("registry_ids")
    save_state(base, newver, files, registry_ids, companions=state.get("companions"))

    print()
    print(f"Wrote {len(written)} file(s). Baseline recorded at {newver}.")
    print("Run the project verify command before committing.")
    return 1 if broken_refs else 0


if __name__ == "__main__":
    sys.exit(main())
