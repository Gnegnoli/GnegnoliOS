#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CALAMARES_REL="packages/gnegnolios-calamares-config/rootfs/etc/calamares"

generate_calamares_config() {

    mkdir -p "$PROJECT_ROOT/$CALAMARES_REL/modules"
    mkdir -p "$PROJECT_ROOT/$CALAMARES_REL/express" "$PROJECT_ROOT/$CALAMARES_REL/guided" "$PROJECT_ROOT/$CALAMARES_REL/advanced"

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


def option_dict(category_id, option_id):
    """Look up the catalog entry (package_groups/profiles) for one option id."""
    if category_id == "usage_profiles":
        return profiles.get(option_id, {})

    group_category = {"kernel": "kernels"}.get(category_id, category_id)
    return groups.get(group_category, {}).get(option_id, {})


def write_packagechooser_conf(category_id, option_ids, mode, default_id=None):
    items = []

    for option_id in option_ids:
        items.append({
            "id": option_id,
            "name": option_dict(category_id, option_id).get("name", option_id),
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

    option_ids = category["options"]

    if not option_ids:
        print(f"ERROR: category '{category_id}' has no options", file=sys.stderr)
        sys.exit(1)

    catalog_dict = profiles if category_id == "usage_profiles" else groups.get(category_id, {})
    for option_id in option_ids:
        if option_id not in catalog_dict:
            print(f"ERROR: option '{option_id}' in category '{category_id}' has no matching package group entry", file=sys.stderr)
            sys.exit(1)

    mode = SELECTION_TO_MODE[category["selection"]]
    default_key = DEFAULTS_KEY.get(category_id)
    default_id = defaults.get(default_key) if default_key else None

    write_packagechooser_conf(category_id, option_ids, mode, default_id)

# Kernel: multiple selection, Advanced-only, no pre-selected default
# (packagechooser optionalmultiple items don't get a safe default in
# this generator — see plan Task 3 notes).
kernels_category = next(c for c in catalog["categories"] if c["id"] == "kernels")
kernel_ids = kernels_category["options"]
if not kernel_ids:
    print("ERROR: category 'kernels' has no options", file=sys.stderr)
    sys.exit(1)
for option_id in kernel_ids:
    if option_id not in groups.get("kernels", {}):
        print(f"ERROR: option '{option_id}' in category 'kernels' has no matching package group entry", file=sys.stderr)
        sys.exit(1)
write_packagechooser_conf("kernel", kernel_ids, "optionalmultiple")

# Drivers: single selection, Advanced-only manual choice. "auto-detect"
# is excluded here — Guided/Express ship the generic mesa baseline
# instead (see packages.conf; automatic vendor-specific driver install
# was found unbuildable with stock Calamares modules, Task 8).
drivers_category = next(c for c in catalog["categories"] if c["id"] == "drivers")
driver_ids = [d for d in drivers_category["options"] if d != "auto-detect"]
if not driver_ids:
    print("ERROR: category 'drivers' has no manual (non-auto-detect) options", file=sys.stderr)
    sys.exit(1)
for option_id in driver_ids:
    if option_id not in groups.get("drivers", {}):
        print(f"ERROR: option '{option_id}' in category 'drivers' has no matching package group entry", file=sys.stderr)
        sys.exit(1)

# Default should be the first catalog-declared driver id that actually
# resolves to real pacman packages under this project's pacman-only
# packages backend (e.g. nvidia-proprietary is AUR-only and would
# resolve to an empty list — see plan review finding).
default_driver_id = next(
    (d for d in driver_ids if resolve_option_packages("drivers", d)),
    driver_ids[0],
)
write_packagechooser_conf("drivers", driver_ids, "required", default_id=default_driver_id)

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

# Full stock Calamares bootloader.conf defaults (verified against
# calamares/src/modules/bootloader/main.py — most keys are read via bare
# dict subscript with no fallback, so a sparse config crashes the job).
# Guided/Express get this as-is (grub fixed, no packagechooser page).
# Advanced additionally gets efiBootLoaderVar so its bootloader chooser
# page actually takes effect (see bootloader-advanced.conf below).
BOOTLOADER_DEFAULTS = {
    "efiBootLoader": "grub",
    "kernelSearchPath": "/usr/lib/modules",
    "kernelPattern": "^vmlinuz.*",
    "loaderEntries": ["timeout 5", "console-mode keep"],
    "kernelParams": ["quiet"],
    "grubInstall": "grub-install",
    "grubMkconfig": "grub-mkconfig",
    "grubCfg": "/boot/grub/grub.cfg",
    "grubProbe": "grub-probe",
    "efiBootMgr": "efibootmgr",
    "installEFIFallback": True,
    "installHybridGRUB": False,
}
(calamares_root / "modules" / "bootloader.conf").write_text(
    "---\n" + yaml.safe_dump(BOOTLOADER_DEFAULTS, sort_keys=False)
)

bootloader_advanced_conf = dict(BOOTLOADER_DEFAULTS)
bootloader_advanced_conf["efiBootLoaderVar"] = "packagechooser_bootloader"
(calamares_root / "modules" / "bootloader-advanced.conf").write_text(
    "---\n" + yaml.safe_dump(bootloader_advanced_conf, sort_keys=False)
)

# Express: fully static package list (no packagechooser pages at all).
# fixed_choices maps a defaults-style key to one chosen option id per
# category; category names here mirror DEFAULTS_KEY (Task 2) inverted.
FIXED_CHOICE_CATEGORY = {
    "browser": "browsers",
    "office_suite": "office_suites",
    "kernel": "kernels",
    "shell": "shells",
    "terminal": "terminals",
    "editor": "editors",
    "theme": "themes",
    "driver": "drivers",
    # filesystem/snapshots are not package-list concerns here:
    # filesystem is handled by partition.conf, snapshots already has
    # its own packagechooser page in Guided/Advanced and Express takes
    # the plain defaults.snapshots value below.
}

express_mode = next(m for m in catalog["modes"] if m["id"] == "express")
express_packages = set()

for profile_id in express_mode.get("include_profiles", []):
    express_packages.update(resolve_option_packages("usage_profiles", profile_id))

for field, option_id in express_mode.get("fixed_choices", {}).items():
    category_id = FIXED_CHOICE_CATEGORY.get(field)
    if category_id is None:
        continue
    express_packages.update(resolve_option_packages(category_id, option_id))

express_packages.update(resolve_option_packages("snapshots", defaults.get("snapshots", "snapper")))

# Generic mesa baseline (same as Guided/Advanced's packages.conf) — Express
# has its own fully-separate packages-express.conf, so it needs this added
# explicitly rather than inheriting it from packages.conf.
express_packages.add("mesa")

if not express_packages:
    print("ERROR: Express mode resolved to zero packages", file=sys.stderr)
    sys.exit(1)

packages_express = {
    "backend": "pacman",
    "skip_if_no_internet": False,
    "update_db": True,
    "update_system": False,
    "pacman": {
        "num_retries": 2,
        "disable_download_timeout": True,
        "needed_only": True,
    },
    "operations": [{"install": sorted(express_packages)}],
}
(calamares_root / "modules" / "packages-express.conf").write_text(
    "---\n" + yaml.safe_dump(packages_express, sort_keys=False)
)

settings_express = {
    "modules-search": ["local"],
    "instances": [
        {"id": "express", "module": "packages", "config": "packages-express.conf"},
    ],
    "sequence": [
        {"show": ["welcome", "locale", "keyboard", "partition", "users", "summary"]},
        {"exec": [
            "partition", "mount", "unpackfs", "machineid", "fstab", "locale",
            "keyboard", "localecfg", "users", "displaymanager", "networkcfg",
            "hwclock", "services-systemd",
            "packages@express", "initcpio", "grubcfg", "bootloader", "umount",
        ]},
        {"show": ["finished"]},
    ],
    "branding": "gnegnolios",
    "prompt-install": True,
    "dont-chroot": False,
    "oem-setup": False,
    "disable-cancel": False,
    "disable-cancel-during-exec": True,
    "hide-back-and-next-during-exec": True,
}
(calamares_root / "express" / "settings.conf").write_text(
    "---\n" + yaml.safe_dump(settings_express, sort_keys=False)
)

guided_category_ids = [c["id"] for c in catalog["categories"] if c["id"] not in ADVANCED_ONLY]


def packagechooser_instances(category_ids):
    return [
        {"id": cid, "module": "packagechooser", "config": f"packagechooser-{cid}.conf"}
        for cid in category_ids
    ]


def build_settings(category_ids, extra_instances, extra_show, extra_exec_before_packages, partition_config=None, bootloader_config=None):
    instances = packagechooser_instances(category_ids) + extra_instances
    if partition_config:
        instances.append({"id": "partition", "module": "partition", "config": partition_config})
    if bootloader_config:
        instances.append({"id": "bootloader", "module": "bootloader", "config": bootloader_config})

    show = (
        ["welcome", "locale", "keyboard"]
        + [f"packagechooser@{cid}" for cid in category_ids]
        + extra_show
        + ["partition", "users", "summary"]
    )

    exec_ = (
        ["partition", "mount", "unpackfs", "machineid", "fstab", "locale",
         "keyboard", "localecfg", "users", "displaymanager", "networkcfg", "hwclock"]
        + extra_exec_before_packages
        + ["services-systemd", "packages", "initcpio", "grubcfg", "bootloader", "umount"]
    )

    return {
        "modules-search": ["local"],
        "instances": instances,
        "sequence": [
            {"show": show},
            {"exec": exec_},
            {"show": ["finished"]},
        ],
        "branding": "gnegnolios",
        "prompt-install": True,
        "dont-chroot": False,
        "oem-setup": False,
        "disable-cancel": False,
        "disable-cancel-during-exec": True,
        "hide-back-and-next-during-exec": True,
    }


settings_guided = build_settings(
    category_ids=guided_category_ids,
    extra_instances=[],
    extra_show=[],
    extra_exec_before_packages=[],
)
(calamares_root / "guided" / "settings.conf").write_text(
    "---\n" + yaml.safe_dump(settings_guided, sort_keys=False)
)

advanced_category_ids = guided_category_ids  # same base categories, plus the three below
settings_advanced = build_settings(
    category_ids=advanced_category_ids,
    extra_instances=[
        {"id": "kernel", "module": "packagechooser", "config": "packagechooser-kernel.conf"},
        {"id": "drivers", "module": "packagechooser", "config": "packagechooser-drivers.conf"},
        {"id": "bootloader", "module": "packagechooser", "config": "packagechooser-bootloader.conf"},
    ],
    extra_show=["packagechooser@kernel", "packagechooser@drivers", "packagechooser@bootloader"],
    extra_exec_before_packages=[],
    partition_config="partition-advanced.conf",
    bootloader_config="bootloader-advanced.conf",
)
(calamares_root / "advanced" / "settings.conf").write_text(
    "---\n" + yaml.safe_dump(settings_advanced, sort_keys=False)
)

# Plain settings.conf is the fallback used when Calamares is launched
# without -c (bypassing gnegnolios-install). Make it identical to
# Guided so a direct launch never regresses to the old "no chooser"
# behavior.
(calamares_root / "settings.conf").write_text(
    "---\n" + yaml.safe_dump(settings_guided, sort_keys=False)
)

print("Generated express/settings.conf, guided/settings.conf, advanced/settings.conf, settings.conf")
PY
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_calamares_config
fi
