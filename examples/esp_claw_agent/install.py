#!/usr/bin/env python3
"""Install the Scintix P4 overlay into an esp-claw checkout.

This example is not a standalone IDF project: it ships only the pieces that are
specific to the Scintix P4 (board definition, demo skills, seed router rules and
schedules). This script drops them into an `esp-claw/application/edge_agent`
checkout, which is where you actually build.

    python install.py --target ../../../esp-claw/application/edge_agent

Copying folders is the easy part. The two seed files under
`fatfs_image/system/.recovery/` already exist upstream and must be *merged*, not
overwritten -- and for the router rules the position matters: our rules have to
sit before the `im_*` rules, because `im_any_message_agent` consumes the event.
That is what this script gets right, and what is easy to get wrong by hand.

Re-running is safe: entries that are already present are left untouched.
"""

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# Overlay directories: (source in this example, destination inside edge_agent)
COPIES = [
    ("board/scintix_p4", "boards/reloc/scintix_p4"),
    ("skills/scintix_display", "fatfs_image/storage/skills/scintix_display"),
    ("skills/news_dashboard", "fatfs_image/storage/skills/news_dashboard"),
    ("skills/market_monitor", "fatfs_image/storage/skills/market_monitor"),
    ("scripts", "fatfs_image/storage/scripts"),
]

ROUTER_RULES = "fatfs_image/system/.recovery/router_rules/router_rules.json"
SCHEDULES = "fatfs_image/system/.recovery/scheduler/schedules.json"

PATCHES = {
    "mcp": "0001-edge_agent-bring-up-the-MCP-server-on-boot.patch",
}


def fail(message):
    sys.exit("error: " + message)


def check_target(target):
    """Make sure we are pointed at an edge_agent checkout, not somewhere else."""
    if not target.is_dir():
        fail("target does not exist: %s" % target)
    for probe in ("main/main.c", "fatfs_image", ROUTER_RULES, SCHEDULES):
        if not (target / probe).exists():
            fail("%s does not look like esp-claw/application/edge_agent "
                 "(missing %s)" % (target, probe))


def copy_overlay(target, dry_run):
    for src_rel, dst_rel in COPIES:
        src, dst = HERE / src_rel, target / dst_rel
        if not src.is_dir():
            fail("missing overlay directory: %s" % src)
        print("  copy  %-26s -> %s" % (src_rel, dst_rel))
        if not dry_run:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copytree(src, dst, dirs_exist_ok=True)


def load_json(path):
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, data, dry_run):
    """Rewrite in the exact style upstream uses, so the diff shows only our
    additions instead of a whole-file reformat."""
    text = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    if not dry_run:
        with path.open("w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)


def merge_router_rules(target, dry_run):
    dst_path = target / ROUTER_RULES
    rules = load_json(dst_path)
    additions = load_json(HERE / "seeds/router_rules.json")
    present = {rule.get("id") for rule in rules}

    # Insert before the first `im_*` rule: `im_any_message_agent` consumes every
    # text message, so anything placed after it would never be evaluated.
    anchor = next((i for i, rule in enumerate(rules)
                   if str(rule.get("id", "")).startswith("im_")), len(rules))

    new = [rule for rule in additions if rule["id"] not in present]
    skipped = [rule["id"] for rule in additions if rule["id"] in present]
    if new:
        print("  merge %-26s +%d rules before index %d (%s)"
              % ("router_rules.json", len(new), anchor,
                 ", ".join(rule["id"] for rule in new)))
        rules[anchor:anchor] = new
        write_json(dst_path, rules, dry_run)
    if skipped:
        print("  keep  %-26s already present: %s"
              % ("router_rules.json", ", ".join(skipped)))


def merge_schedules(target, dry_run):
    dst_path = target / SCHEDULES
    schedules = load_json(dst_path)
    additions = load_json(HERE / "seeds/schedules.json")
    present = {item.get("id") for item in schedules}

    new = [item for item in additions if item["id"] not in present]
    skipped = [item["id"] for item in additions if item["id"] in present]
    if new:
        print("  merge %-26s +%d schedules (%s)"
              % ("schedules.json", len(new),
                 ", ".join(item["id"] for item in new)))
        schedules.extend(new)
        write_json(dst_path, schedules, dry_run)
    if skipped:
        print("  keep  %-26s already present: %s"
              % ("schedules.json", ", ".join(skipped)))


def apply_patches(target, names, dry_run):
    """Patch paths are relative to the esp-claw repository root, so git apply
    has to run from there rather than from edge_agent."""
    repo_root = target.parent.parent
    if not (repo_root / ".git").exists():
        fail("%s is not a git checkout, cannot apply patches; apply them by "
             "hand (see the README)" % repo_root)
    for name in names:
        patch = HERE / "patches" / PATCHES[name]
        if not patch.is_file():
            fail("missing patch file: %s" % patch)
        print("  patch %-26s (%s)" % (name, patch.name))
        if dry_run:
            continue
        check = subprocess.run(["git", "apply", "--check", str(patch)],
                               cwd=repo_root, capture_output=True, text=True)
        if check.returncode != 0:
            reverse = subprocess.run(
                ["git", "apply", "--reverse", "--check", str(patch)],
                cwd=repo_root, capture_output=True, text=True)
            if reverse.returncode == 0:
                print("        already applied, skipping")
                continue
            fail("cannot apply %s:\n%s" % (patch.name, check.stderr.strip()))
        subprocess.run(["git", "apply", str(patch)], cwd=repo_root, check=True)


def main():
    parser = argparse.ArgumentParser(
        description="Install the Scintix P4 ESP-Claw overlay.")
    parser.add_argument("--target", required=True, type=Path,
                        help="path to esp-claw/application/edge_agent")
    parser.add_argument("--patches", default="",
                        help="comma separated C patches to apply: mcp, all, none "
                             "(default: none)")
    parser.add_argument("--dry-run", action="store_true",
                        help="print what would happen, change nothing")
    args = parser.parse_args()

    selected = [name for name in args.patches.split(",") if name.strip()]
    if "all" in selected:
        selected = list(PATCHES)
    if "none" in selected:
        selected = []
    unknown = [name for name in selected if name not in PATCHES]
    if unknown:
        fail("unknown patch(es): %s (known: %s, all, none)"
             % (", ".join(unknown), ", ".join(PATCHES)))

    target = args.target.resolve()
    check_target(target)
    print("%sinstalling into %s" % ("[dry run] " if args.dry_run else "", target))

    copy_overlay(target, args.dry_run)
    merge_router_rules(target, args.dry_run)
    merge_schedules(target, args.dry_run)
    if selected:
        apply_patches(target, selected, args.dry_run)

    print("done. next: idf.py set-target esp32p4 && "
          "idf.py bmgr -c ./boards -b scintix_p4 && idf.py build")


if __name__ == "__main__":
    main()
