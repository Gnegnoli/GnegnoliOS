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

    # Map singular output names to plural group names
    group_category = {"kernel": "kernels"}.get(category_id, category_id)
    option = groups.get(group_category, {}).get(option_id, {})
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

# Kernel: multiple selection, Advanced-only, no pre-selected default
# (packagechooser optionalmultiple items don't get a safe default in
# this generator — see plan Task 3 notes).
kernel_ids = list(groups.get("kernels", {}).keys())
if not kernel_ids:
    print("ERROR: category 'kernels' has no options", file=sys.stderr)
    sys.exit(1)
write_packagechooser_conf("kernel", kernel_ids, "optionalmultiple")

# Drivers: single selection, Advanced-only manual choice. "auto-detect"
# is excluded here — Guided/Express use the shellprocess auto-detect
# script (Task 8) instead of this chooser.
driver_ids = [d for d in groups.get("drivers", {}).keys() if d != "auto-detect"]
if not driver_ids:
    print("ERROR: category 'drivers' has no manual (non-auto-detect) options", file=sys.stderr)
    sys.exit(1)
write_packagechooser_conf("drivers", driver_ids, "required", default_id=driver_ids[0])

# Filesystem: not a packagechooser. Guided/Express get a fixed
# defaultFileSystemType with no dropdown. Advanced gets the same
# default plus availableFileSystemTypes, which Calamares' partition
# module natively renders as a dropdown on the automatic/erase-disk
# partitioning page (verified against partition/Config.cpp — see
# design spec's Constraints section).
filesystem_category = next(c for c in catalog["categories"] if c["id"] == "filesystems")
fs_options = filesystem_category["options"]

if not fs_options:
    print("ERROR: category 'filesystems' has no options", file=sys.stderr)
    sys.exit(1)

default_fs = defaults.get("filesystem", fs_options[0])

partition_fixed = {"defaultFileSystemType": default_fs}
(calamares_root / "modules" / "partition.conf").write_text(
    "---\n" + yaml.safe_dump(partition_fixed, sort_keys=False)
)

partition_advanced = {
    "defaultFileSystemType": default_fs,
    "availableFileSystemTypes": fs_options,
}
(calamares_root / "modules" / "partition-advanced.conf").write_text(
    "---\n" + yaml.safe_dump(partition_advanced, sort_keys=False)
)

# Bootloader: not in installer.yaml's categories (it's a Calamares-level
# choice, not a package category) — items are literal here.
bootloader_doc = {
    "mode": "required",
    "method": "legacy",
    "items": [
        {"id": "grub", "name": "GRUB"},
        {"id": "systemd-boot", "name": "systemd-boot"},
    ],
    "default": "grub",
}
(calamares_root / "modules" / "packagechooser-bootloader.conf").write_text(
    "---\n" + yaml.safe_dump(bootloader_doc, sort_keys=False)
)

bootloader_conf = {"efiBootLoaderVar": "packagechooser_bootloader"}
(calamares_root / "modules" / "bootloader.conf").write_text(
    "---\n" + yaml.safe_dump(bootloader_conf, sort_keys=False)
)

print("Generated packagechooser configs for: "
      + ", ".join(c["id"] for c in catalog["categories"] if c["id"] not in ADVANCED_ONLY))
PY
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_calamares_config
fi
