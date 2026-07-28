#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CALAMARES_REL="packages/gnegnolios-calamares-config/rootfs/etc/calamares"

generate_calamares_config() {

    mkdir -p "$CALAMARES_REL/modules"

    python3 - "$PROJECT_ROOT" "$CALAMARES_REL" <<'PY'
import pathlib
import sys

import yaml

root = pathlib.Path(sys.argv[1])
calamares_root = root / sys.argv[2]
catalog = yaml.safe_load((root / "config/installer.yaml").read_text())

groups = catalog.get("package_groups", {})
profiles = catalog.get("profiles", {})

# Category ids handled by the generic packagechooser loop in this task.
# drivers/kernels/filesystems get their own generators (Task 3/4).
ADVANCED_ONLY = {"drivers", "kernels", "filesystems"}

# Category id -> defaults.yaml key, for pre-selection. Categories with no
# entry here get no `default:` in their generated conf.
DEFAULTS_KEY = {
    "browsers": "browser",
    "office_suites": "office_suite",
    "snapshots": "snapshots",
    "shells": "shell",
    "terminals": "terminal",
    "editors": "editor",
    "themes": "theme",
}

SELECTION_TO_MODE = {
    "single": "required",
    "multiple": "optionalmultiple",
}


def resolve_option_packages(category_id, option_id):
    """Flat, deduplicated, sorted list of pacman package names for one option.

    Resolves one level of `includes:` (e.g. office_suites.both.includes).
    Only `packages.pacman` is used — aur/flatpak entries are intentionally
    skipped (see Global Constraints in the plan: packages module backend
    is pacman-only).
    """
    if category_id == "usage_profiles":
        option = profiles.get(option_id, {})
        pkgs = set(option.get("packages", {}).get("pacman", []))
        return sorted(pkgs)

    option = groups.get(category_id, {}).get(option_id, {})
    pkgs = set(option.get("packages", {}).get("pacman", []))

    for included_id in option.get("includes", []):
        included = groups.get(category_id, {}).get(included_id, {})
        pkgs.update(included.get("packages", {}).get("pacman", []))

    return sorted(pkgs)


def write_packagechooser_conf(category_id, option_ids, mode, default_id=None):
    items = []

    for option_id in option_ids:
        items.append({
            "id": option_id,
            "name": option_id,
            "packages": resolve_option_packages(category_id, option_id),
        })

    doc = {
        "mode": mode,
        "method": "packages",
        "items": items,
    }

    if default_id is not None and mode == "required":
        doc["default"] = default_id

    out_path = calamares_root / "modules" / f"packagechooser-{category_id}.conf"
    out_path.write_text("---\n" + yaml.safe_dump(doc, sort_keys=False))


defaults = catalog.get("defaults", {})

for category in catalog["categories"]:
    category_id = category["id"]

    if category_id in ADVANCED_ONLY:
        continue

    if category_id == "usage_profiles":
        option_ids = list(profiles.keys())
    else:
        option_ids = list(groups.get(category_id, {}).keys())

    if not option_ids:
        print(f"ERROR: category '{category_id}' has no options", file=sys.stderr)
        sys.exit(1)

    mode = SELECTION_TO_MODE[category["selection"]]
    default_key = DEFAULTS_KEY.get(category_id)
    default_id = defaults.get(default_key) if default_key else None

    write_packagechooser_conf(category_id, option_ids, mode, default_id)

print("Generated packagechooser configs for: "
      + ", ".join(c["id"] for c in catalog["categories"] if c["id"] not in ADVANCED_ONLY))
PY
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_calamares_config
fi
