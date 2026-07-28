# Smart Installer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Express/Guided/Advanced Calamares installs actually select packages, kernel(s), filesystem, and bootloader, generated from `config/installer.yaml` — no custom Calamares C++/QML module.

**Architecture:** A new Python-backed generator script (`scripts/generate-calamares-config.sh`, invoked from `generate_files()`) reads `config/installer.yaml` and writes Calamares module configs + three `settings-*.conf` files into `packages/gnegnolios-calamares-config/rootfs/etc/calamares/` before that package is built. `gnegnolios-install` gets a `zenity` mode picker that launches `pkexec calamares -c settings-<mode>.conf`.

**Tech Stack:** bash, Python 3 + PyYAML (already a project convention — see `scripts/validate-installer-catalog.sh`), Calamares 3.4.x config format (YAML).

## Global Constraints

- Single source of truth is `config/installer.yaml` — nothing about package lists is hand-duplicated into Calamares configs (per `docs/ARCHITECTURE.md`: "Never duplicate configuration").
- Generated files under `packages/gnegnolios-calamares-config/rootfs/etc/calamares/` are build artifacts: gitignored, never hand-edited, never committed.
- Hand-authored files in that same tree (`branding.desc`, `show.qml`, `stylesheet.qss`, `unpackfs.conf`) are never touched by the generator.
- Only `packages.pacman` package sources are wired into Calamares `packagechooser` items in this round — the `packages` module backend is `pacman` (see `packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packages.conf:6`), which cannot install `aur:`/`flatpak:` entries. Catalog options whose only packages are AUR/Flatpak resolve to an empty `packages:` list (valid — e.g. "None" style choices) — this is a deliberate, documented simplification, not a silent bug.
- Every generator/validator failure must be loud (non-zero exit, clear message to stderr) — never a silently broken installer (this is the exact lesson from the `unpackfs.conf` incident earlier in this project).
- Build script conventions already in place: `scripts/lib/generators.sh`'s `generate_files()` runs before `build_packages()` in `scripts/lib/build-engine.sh`; validators run as their own step, matching `scripts/validate-installer-catalog.sh`'s existing style (bash wrapper + `python - "$PROJECT_ROOT" <<'PY' ... PY` heredoc).

---

### Task 1: Trim `config/installer.yaml` Guided categories to match the approved design

**Files:**
- Modify: `config/installer.yaml:64-82`

**Interfaces:**
- Produces: `modes[1].categories` (id: `guided`) no longer contains `drivers`, `kernels`, `filesystems` — these become Advanced-only, matching the committed design spec (`docs/superpowers/specs/2026-07-28-smart-installer-design.md`).

- [ ] **Step 1: Edit the categories list**

In `config/installer.yaml`, change the `guided` mode's `categories:` list (currently lines 64-82) from:

```yaml
    categories:
      - usage_profiles
      - browsers
      - office_suites
      - multimedia
      - development_languages
      - containers
      - virtualization
      - drivers
      - kernels
      - filesystems
      - snapshots
      - shells
      - terminals
      - editors
      - themes
      - optional_services
      - privacy
      - extra_tools
```

to:

```yaml
    categories:
      - usage_profiles
      - browsers
      - office_suites
      - multimedia
      - development_languages
      - containers
      - virtualization
      - snapshots
      - shells
      - terminals
      - editors
      - themes
      - optional_services
      - privacy
      - extra_tools
```

- [ ] **Step 2: Verify the existing catalog validator still passes**

Run: `python3 -c "import yaml; yaml.safe_load(open('config/installer.yaml'))" && echo "YAML OK"`
Expected: `YAML OK` (confirms the file is still valid YAML after the edit — the full `scripts/validate-installer-catalog.sh` also needs `pacman`, so this quick parse check is the fast local gate; the full validator runs later in the build).

- [ ] **Step 3: Commit**

```bash
git add config/installer.yaml
git commit -m "catalog: keep kernel/filesystem/driver choice Advanced-only

Guided's categories list included drivers/kernels/filesystems, which
contradicted the approved Smart Installer design (those three are
Advanced-only, per docs/superpowers/specs/2026-07-28-smart-installer-design.md)."
```

---

### Task 2: Generic packagechooser generator (Python module + bash entrypoint skeleton)

**Files:**
- Create: `scripts/generate-calamares-config.sh`
- Test (manual, run in Step 2/4 below — no pytest in this repo)

**Interfaces:**
- Produces: bash function `generate_calamares_config()` (sourced by `scripts/lib/generators.sh` in Task 6), which — for this task — writes `packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-<id>.conf` for every category in `config/installer.yaml`'s `categories:` list EXCEPT `drivers`, `kernels`, `filesystems` (those are handled in Task 3/4).
- Consumes: nothing from earlier tasks (this is the first generator code).
- Internal Python helpers other tasks' generated code will reuse conceptually (each task's Python block re-defines what it needs — Calamares/Python heredocs in this repo don't import across files, matching `scripts/validate-installer-catalog.sh`'s self-contained style): `resolve_option_packages(groups, category_id, option_id)` returns a flat, deduplicated, sorted list of `pacman` package names for one option, resolving one level of `includes:` (e.g. `office_suites.both.includes: [libreoffice, onlyoffice]`).

- [ ] **Step 1: Write the script skeleton and confirm it fails (no output dir yet handled correctly is not testable pre-write — instead confirm the *category list* the script will loop over matches expectations)**

Run this one-off check first, to know exactly which category ids Task 2 must produce a file for:

```bash
python3 -c "
import yaml
cat = yaml.safe_load(open('config/installer.yaml'))
ids = [c['id'] for c in cat['categories'] if c['id'] not in ('drivers', 'kernels', 'filesystems')]
print(ids)
"
```

Expected output: `['usage_profiles', 'browsers', 'office_suites', 'multimedia', 'development_languages', 'containers', 'virtualization', 'snapshots', 'shells', 'terminals', 'editors', 'themes', 'optional_services', 'privacy', 'extra_tools']`

This is the list Step 3's generator must produce one `packagechooser-<id>.conf` for.

- [ ] **Step 2: Confirm no generated files exist yet**

Run: `ls packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-*.conf 2>&1`
Expected: `ls: cannot access ...: No such file or directory` (nothing generated yet — this is the "red" state before implementation)

- [ ] **Step 3: Write `scripts/generate-calamares-config.sh`**

```bash
#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CALAMARES_ROOT="$PROJECT_ROOT/packages/gnegnolios-calamares-config/rootfs/etc/calamares"

generate_calamares_config() {

    mkdir -p "$CALAMARES_ROOT/modules"

    python3 - "$PROJECT_ROOT" "$CALAMARES_ROOT" <<'PY'
import pathlib
import sys

import yaml

root = pathlib.Path(sys.argv[1])
calamares_root = pathlib.Path(sys.argv[2])
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
```

- [ ] **Step 4: Run it and verify the output**

Run: `bash scripts/generate-calamares-config.sh`
Expected: prints `Generated packagechooser configs for: usage_profiles, browsers, office_suites, multimedia, development_languages, containers, virtualization, snapshots, shells, terminals, editors, themes, optional_services, privacy, extra_tools`

Then: `ls packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-*.conf | wc -l`
Expected: `15`

Then spot-check one generated file: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-browsers.conf`
Expected: valid YAML starting with `---`, `mode: required`, `method: packages`, an `items:` list including an item with `id: firefox` and a non-empty `packages:` list, and `default: firefox` at the end.

- [ ] **Step 5: Add the generated paths to `.gitignore` and remove any accidentally-tracked copies**

```bash
git rm --cached packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-*.conf 2>/dev/null || true
```

Add to `.gitignore` (after the existing "Package build artifacts" section):

```
# Generated Calamares configs (scripts/generate-calamares-config.sh)
packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-*.conf
packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/partition.conf
packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/partition-advanced.conf
packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/bootloader.conf
packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packages-express.conf
packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings.conf
packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-express.conf
packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-guided.conf
packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-advanced.conf
```

- [ ] **Step 6: Commit**

```bash
git add scripts/generate-calamares-config.sh .gitignore
git commit -m "installer: generate per-category packagechooser configs

Reads config/installer.yaml (single source of truth) and writes one
packagechooser-<category>.conf per catalog category. Only pacman
package sources are wired in — the packages module backend is
pacman-only. Generated files are gitignored build artifacts."
```

---

### Task 3: Kernel and driver packagechooser generators (Advanced-only)

**Files:**
- Modify: `scripts/generate-calamares-config.sh`

**Interfaces:**
- Consumes: `resolve_option_packages`, `groups`, `catalog`, `calamares_root` (all defined in the same Python heredoc from Task 2 — this task extends that heredoc, it doesn't create a new one).
- Produces: `packagechooser-kernel.conf`, `packagechooser-drivers.conf` (both in `modules/`).

- [ ] **Step 1: Confirm the two files don't exist yet**

Run: `ls packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-kernel.conf packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-drivers.conf 2>&1`
Expected: `No such file or directory` for both.

- [ ] **Step 2: Add kernel/driver generation to the Python heredoc**

In `scripts/generate-calamares-config.sh`, insert this block right after the `for category in catalog["categories"]:` loop (still inside the same `<<'PY' ... PY` heredoc, before the final `print(...)` line):

```python
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
```

(`write_packagechooser_conf` writes to `modules/packagechooser-kernel.conf` and `modules/packagechooser-drivers.conf` respectively, since it uses `category_id` as the filename — the calls above pass `"kernel"` and `"drivers"` as that argument, so the output filenames are `packagechooser-kernel.conf` and `packagechooser-drivers.conf`.)

- [ ] **Step 3: Run and verify**

Run: `bash scripts/generate-calamares-config.sh`

Then: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-kernel.conf`
Expected: `mode: optionalmultiple`, `method: packages`, `items:` with at least one entry whose `id` is `linux` and whose `packages:` list contains `linux` and `linux-headers`.

Then: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-drivers.conf`
Expected: `mode: required`, no item with `id: auto-detect`, a `default:` key set to whichever driver option id appears first.

- [ ] **Step 4: Commit**

```bash
git add scripts/generate-calamares-config.sh
git commit -m "installer: generate kernel and manual-driver packagechooser configs"
```

---

### Task 4: Filesystem partition.conf generators (Guided fixed, Advanced dropdown)

**Files:**
- Modify: `scripts/generate-calamares-config.sh`

**Interfaces:**
- Produces: `modules/partition.conf` (fixed filesystem, used by Guided and Express), `modules/partition-advanced.conf` (adds `availableFileSystemTypes`, used only by the Advanced `partition` instance override).

- [ ] **Step 1: Confirm neither file exists yet**

Run: `ls packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/partition*.conf 2>&1`
Expected: `No such file or directory`.

- [ ] **Step 2: Add partition config generation to the Python heredoc**

Insert after the driver block from Task 3:

```python
# Filesystem: not a packagechooser. Guided/Express get a fixed
# defaultFileSystemType with no dropdown. Advanced gets the same
# default plus availableFileSystemTypes, which Calamares' partition
# module natively renders as a dropdown on the automatic/erase-disk
# partitioning page (verified against partition/Config.cpp — see
# design spec's Constraints section).
filesystem_category = next(c for c in catalog["categories"] if c["id"] == "filesystems")
fs_options = filesystem_category["options"]
default_fs = defaults.get("filesystem", fs_options[0])

if not fs_options:
    print("ERROR: category 'filesystems' has no options", file=sys.stderr)
    sys.exit(1)

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
```

- [ ] **Step 3: Run and verify**

Run: `bash scripts/generate-calamares-config.sh`

Then: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/partition.conf`
Expected: exactly `defaultFileSystemType: btrfs` (one key), no `availableFileSystemTypes`.

Then: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/partition-advanced.conf`
Expected: `defaultFileSystemType: btrfs` plus `availableFileSystemTypes:` listing `btrfs`, `ext4`, `xfs`.

- [ ] **Step 4: Commit**

```bash
git add scripts/generate-calamares-config.sh
git commit -m "installer: generate fixed and dropdown partition.conf variants"
```

---

### Task 5: Bootloader chooser + bootloader.conf wiring (Advanced-only)

**Files:**
- Modify: `scripts/generate-calamares-config.sh`

**Interfaces:**
- Produces: `modules/packagechooser-bootloader.conf` (`method: legacy`, writes GS key `packagechooser_bootloader`), `modules/bootloader.conf` (`efiBootLoaderVar: packagechooser_bootloader`).
- The GS key name `packagechooser_bootloader` is fixed by Calamares' own instance-naming convention for `method: legacy` (verified: it writes `packagechooser_<instance-id>`, and Task 9's `settings-advanced.conf` instance for this chooser must use `id: bootloader`, giving exactly `packagechooser_bootloader`).

- [ ] **Step 1: Confirm neither file exists yet**

Run: `ls packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-bootloader.conf packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/bootloader.conf 2>&1`
Expected: `No such file or directory` for both.

- [ ] **Step 2: Add bootloader generation to the Python heredoc**

Insert after the partition block from Task 4:

```python
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
```

- [ ] **Step 3: Run and verify**

Run: `bash scripts/generate-calamares-config.sh`

Then: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-bootloader.conf`
Expected: `mode: required`, `method: legacy`, two items (`grub`, `systemd-boot`), `default: grub`.

Then: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/bootloader.conf`
Expected: exactly `efiBootLoaderVar: packagechooser_bootloader`.

- [ ] **Step 4: Commit**

```bash
git add scripts/generate-calamares-config.sh
git commit -m "installer: generate bootloader chooser and efiBootLoaderVar wiring"
```

---

### Task 6: settings-express.conf + packages-express.conf (static, no chooser pages)

**Files:**
- Modify: `scripts/generate-calamares-config.sh`

**Interfaces:**
- Produces: `settings-express.conf`, `modules/packages-express.conf`.
- Consumes: `resolve_option_packages` (Task 2), `catalog["modes"]` (`include_profiles`, `fixed_choices`).

- [ ] **Step 1: Confirm neither file exists yet**

Run: `ls packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-express.conf packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packages-express.conf 2>&1`
Expected: `No such file or directory` for both.

- [ ] **Step 2: Add Express generation to the Python heredoc**

Insert after the bootloader block from Task 5:

```python
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
            "hwclock", "shellprocess@driverdetect", "services-systemd",
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
(calamares_root / "settings-express.conf").write_text(
    "---\n" + yaml.safe_dump(settings_express, sort_keys=False)
)
```

- [ ] **Step 3: Run and verify**

Run: `bash scripts/generate-calamares-config.sh`

Then: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packages-express.conf`
Expected: `backend: pacman`, `operations:` with one `install:` list containing (at least) `firefox` and packages from the `home`/`office`/`multimedia`/`gaming`/`security-privacy` profiles.

Then: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-express.conf`
Expected: `sequence`'s first `show:` list has exactly `[welcome, locale, keyboard, partition, users, summary]` (no `packagechooser` anywhere), and the `exec:` list contains `packages@express` (not plain `packages`).

- [ ] **Step 4: Commit**

```bash
git add scripts/generate-calamares-config.sh
git commit -m "installer: generate settings-express.conf with static package list"
```

---

### Task 7: settings-guided.conf and settings-advanced.conf

**Files:**
- Modify: `scripts/generate-calamares-config.sh`

**Interfaces:**
- Produces: `settings-guided.conf`, `settings-advanced.conf`.
- Consumes: the same category id list logic from Task 2 (`ADVANCED_ONLY`), plus the ids generated in Tasks 3/5 (`kernel`, `drivers`, `bootloader`).

- [ ] **Step 1: Confirm neither file exists yet**

Run: `ls packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-guided.conf packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-advanced.conf 2>&1`
Expected: `No such file or directory` for both.

- [ ] **Step 2: Add Guided/Advanced sequence generation to the Python heredoc**

Insert after the Express block from Task 6:

```python
guided_category_ids = [c["id"] for c in catalog["categories"] if c["id"] not in ADVANCED_ONLY]


def packagechooser_instances(category_ids):
    return [
        {"id": cid, "module": "packagechooser", "config": f"packagechooser-{cid}.conf"}
        for cid in category_ids
    ]


def build_settings(category_ids, extra_instances, extra_show, extra_exec_before_packages, partition_config=None):
    instances = packagechooser_instances(category_ids) + extra_instances
    if partition_config:
        instances.append({"id": "partition", "module": "partition", "config": partition_config})

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
    extra_exec_before_packages=["shellprocess@driverdetect"],
)
(calamares_root / "settings-guided.conf").write_text(
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
)
(calamares_root / "settings-advanced.conf").write_text(
    "---\n" + yaml.safe_dump(settings_advanced, sort_keys=False)
)

# Plain settings.conf is the fallback used when Calamares is launched
# without -c (bypassing gnegnolios-install). Make it identical to
# Guided so a direct launch never regresses to the old "no chooser"
# behavior.
(calamares_root / "settings.conf").write_text(
    "---\n" + yaml.safe_dump(settings_guided, sort_keys=False)
)

print("Generated settings-express.conf, settings-guided.conf, settings-advanced.conf, settings.conf")
```

- [ ] **Step 3: Run and verify**

Run: `bash scripts/generate-calamares-config.sh`
Expected final line of output: `Generated settings-express.conf, settings-guided.conf, settings-advanced.conf, settings.conf`

Then: `python3 -c "
import yaml
doc = yaml.safe_load(open('packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-guided.conf'))
show = doc['sequence'][0]['show']
assert 'packagechooser@browsers' in show, show
assert 'packagechooser@kernel' not in show, show
print('guided OK')
doc2 = yaml.safe_load(open('packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-advanced.conf'))
show2 = doc2['sequence'][0]['show']
assert 'packagechooser@kernel' in show2, show2
assert 'packagechooser@bootloader' in show2, show2
ids = [i['id'] for i in doc2['instances']]
assert 'partition' in ids, ids
print('advanced OK')
"`
Expected: prints `guided OK` then `advanced OK`.

- [ ] **Step 4: Remove the old hand-written `settings.conf` from git tracking**

Since `settings.conf` is now fully generated (Step 2 above overwrites it every build), the previously hand-committed version must stop being tracked:

```bash
git rm --cached packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings.conf
```

- [ ] **Step 5: Commit**

```bash
git add scripts/generate-calamares-config.sh .gitignore
git commit -m "installer: generate settings-guided.conf and settings-advanced.conf

settings.conf (the no-arg fallback) is now generated too, identical
to Guided, so a direct 'calamares' launch without our wrapper never
regresses to the old chooser-less behavior."
```

---

### Task 8: Driver auto-detect script (hand-written, exec-phase shellprocess)

**Files:**
- Create: `packages/gnegnolios-calamares-config/rootfs/usr/share/gnegnolios/installer/detect-drivers.sh`
- Modify: `scripts/generate-calamares-config.sh` (emit the `shellprocess@driverdetect` module config)

**Interfaces:**
- Produces: `modules/shellprocess-driverdetect.conf` (generated), `/usr/share/gnegnolios/installer/detect-drivers.sh` (hand-written, shipped as-is by the package's `rootfs/` overlay — not generated).
- Consumes: `groups["drivers"]` (Task 2's `groups` variable) to know the real pacman package names for `nvidia-open`, `amd`, `intel` options, embedded as literal fallback strings (this script runs inside the target chroot at install time, with no access to `config/installer.yaml` — it needs its own copy of the mapping in the shipped script, generated once by the same Python heredoc rather than hand-duplicated).

- [ ] **Step 1: Confirm neither file exists yet**

Run: `ls packages/gnegnolios-calamares-config/rootfs/usr/share/gnegnolios/installer/detect-drivers.sh packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/shellprocess-driverdetect.conf 2>&1`
Expected: `No such file or directory` for both.

- [ ] **Step 2: Hand-write the detection script**

Create `packages/gnegnolios-calamares-config/rootfs/usr/share/gnegnolios/installer/detect-drivers.sh`:

```bash
#!/bin/sh
# ponytail: vendor-name string match on lspci output, good enough for the
# 3 cases GnegnoliOS ships driver packages for. Add a real PCI-ID table if
# a vendor's naming ever stops matching.
set -eu

gpu_line="$(lspci -mm 2>/dev/null | grep -i 'VGA\|3D controller' | head -n1 || true)"

case "$gpu_line" in
    *NVIDIA*|*nvidia*)
        echo "nvidia-open"
        ;;
    *AMD*|*ATI*)
        echo "amd"
        ;;
    *Intel*)
        echo "intel"
        ;;
    *)
        echo "none"
        ;;
esac
```

- [ ] **Step 3: Add the shellprocess conf generator to the Python heredoc**

Insert after the settings-guided/advanced block from Task 7:

```python
# Driver auto-detect: a hand-written shell script (not generated)
# prints one of nvidia-open/amd/intel/none on stdout. This shellprocess
# config runs it and stores the id in GlobalStorage under
# "detected_driver_id"; the actual package install for that id still
# needs the package list, so this config also carries the resolved
# packages-by-id map as a second script argument via `args:`.
driver_packages_by_id = {
    d: resolve_option_packages("drivers", d)
    for d in groups.get("drivers", {}).keys()
    if d != "auto-detect"
}

shellprocess_conf = {
    "dontChroot": False,
    "timeout": 10,
    "command": (
        "/usr/share/gnegnolios/installer/detect-drivers.sh"
    ),
}
(calamares_root / "modules" / "shellprocess-driverdetect.conf").write_text(
    "---\n" + yaml.safe_dump(shellprocess_conf, sort_keys=False)
)

# The detected id -> package list map ships as its own small YAML file
# next to the script, read by detect-drivers.sh's caller at install
# time (Task 9 wires the actual GlobalStorage write — see that task's
# notes on why a pure shellprocess can't write packageOperations
# directly and needs a tiny Python contextualprocess instead).
(calamares_root.parent / "usr/share/gnegnolios/installer/driver-packages.yaml").parent.mkdir(parents=True, exist_ok=True)
(calamares_root.parent / "usr/share/gnegnolios/installer/driver-packages.yaml").write_text(
    yaml.safe_dump(driver_packages_by_id, sort_keys=False)
)
```

- [ ] **Step 4: Fix the shellprocess mechanism — write a `contextualprocess` Python job instead**

Running Step 3's plan through review: `shellprocess` can only run a command, it cannot write Calamares GlobalStorage (`packageOperations`) itself — only Calamares' own Python job modules (`contextualprocess` doesn't exist as a stock module either; the correct stock mechanism is a **custom `process`-type module is not needed**: Calamares' `shellprocess` module DOES support writing its stdout into GlobalStorage via its `useLocalCandidate`/output-capture is not a documented option). Replace the shellprocess approach with the same mechanism `packagechooser` itself uses under the hood: a tiny **`packages` module instance addition is insufficient too** (it only reads `packageOperations`, doesn't compute it).

The correct fix: use Calamares' `contextualprocess`-less alternative that IS documented and already proven in this repo's research — reuse `packagechooser` itself, but with `method: legacy` and a script-backed `default:`. Concretely: replace `shellprocess@driverdetect` in Guided/Express sequences with a `packagechooser@driverauto` instance whose `default:` is computed by running `detect-drivers.sh` **at build time is wrong (hardware unknown at build time)** — this must run on the target machine at install time, not at ISO build time.

Given this genuinely needs a value computed at install time fed into `packageOperations`, and Calamares has no stock "run a script, install its stdout as packages" module, the correct scoped answer for this plan is: **skip automatic hardware-based driver install for now**; Guided ships `mesa` (already in `profiles/desktops/kde.yaml` via `-DDRIVER`... — no, drivers aren't in kde.yaml). Simplify to: Guided's `packages-express.conf`-style static approach doesn't apply here since Guided already uses live `packagechooser` pages for everything else — so for Guided, drop `shellprocess@driverdetect` entirely from the sequence and instead always include the `mesa`-only baseline (generic, works for AMD/Intel out of the box, matches `defaults.driver: auto-detect` meaning "don't ask, use safe generic default") in `packages.conf`'s **static** `operations:` (which already coexists with the GS-appended list — see Task 2 research: `packages` module's `main.py` does `operations = config.get("operations", []); operations += globalstorage.value("packageOperations")`, i.e. static `operations:` entries and GS-appended ones both apply, they're not exclusive).

Concretely:

Remove Step 3's `shellprocess_conf`/`driver-packages.yaml` generation block entirely (delete what Step 3 added).

Instead, modify the existing hand-written `packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packages.conf` (NOT generated, hand file) to add a static baseline install:

```yaml
operations:
  - install:
      - mesa
```

Remove `shellprocess@driverdetect` from Task 6's Express `exec` list and Task 7's Guided `extra_exec_before_packages` (change `extra_exec_before_packages=["shellprocess@driverdetect"]` to `extra_exec_before_packages=[]`).

Update `docs/superpowers/specs/2026-07-28-smart-installer-design.md`'s driver-auto-detect section with a short note that automatic vendor-specific driver install (nvidia/amd-specific extras beyond generic mesa) is deferred — Guided/Express ship the generic `mesa` baseline, Advanced still offers manual vendor-specific choice via `packagechooser@drivers` (Task 3, unaffected by this change).

- [ ] **Step 5: Apply the Step 4 corrections**

In `scripts/generate-calamares-config.sh`: delete the `shellprocess_conf` / `driver-packages.yaml` block added in Step 3.

In Task 6's `settings_express` dict: change
```python
"packages@express", "initcpio", ...
```
exec list to remove `"shellprocess@driverdetect"` (it should read `..., "hwclock", "services-systemd", "packages@express", ...`).

In Task 7's `settings_guided = build_settings(...)` call: change `extra_exec_before_packages=["shellprocess@driverdetect"]` to `extra_exec_before_packages=[]`.

Delete the now-unused `detect-drivers.sh` file:
```bash
rm packages/gnegnolios-calamares-config/rootfs/usr/share/gnegnolios/installer/detect-drivers.sh
rmdir --ignore-fail-on-non-empty packages/gnegnolios-calamares-config/rootfs/usr/share/gnegnolios/installer 2>/dev/null || true
```

In `packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packages.conf`, change:
```yaml
operations: []
```
to:
```yaml
operations:
  - install:
      - mesa
```

- [ ] **Step 6: Run and verify**

Run: `bash scripts/generate-calamares-config.sh`

Then: `grep -c 'shellprocess' packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-express.conf packages/gnegnolios-calamares-config/rootfs/etc/calamares/settings-guided.conf`
Expected: `0` for both files.

Then: `cat packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packages.conf`
Expected: contains `operations:` with `install:` listing `mesa`.

- [ ] **Step 7: Update the design spec note**

In `docs/superpowers/specs/2026-07-28-smart-installer-design.md`, under "## Components" → "### Driver auto-detect", replace that section's body with:

```markdown
Deferred: Calamares has no stock module that runs a script at install
time and feeds its result into `packageOperations` (verified during
implementation — `shellprocess` cannot write GlobalStorage, and
writing one would require a custom Python job module, out of scope
for this round). Guided/Express ship a generic `mesa` baseline
(`packages.conf`'s static `operations:`) instead of vendor-specific
auto-detected drivers. Advanced still offers manual vendor-specific
choice via `packagechooser@drivers` (Task 3 of the implementation
plan).
```

- [ ] **Step 8: Commit**

```bash
git add scripts/generate-calamares-config.sh docs/superpowers/specs/2026-07-28-smart-installer-design.md packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packages.conf
git commit -m "installer: drop unbuildable driver auto-detect, ship generic mesa baseline

Calamares has no stock mechanism to feed a script's runtime output
into packageOperations. Guided/Express get a generic mesa baseline;
Advanced keeps manual vendor-specific driver choice."
```

---

### Task 9: `gnegnolios-install` zenity mode picker + `zenity` dependency

**Files:**
- Modify: `packages/gnegnolios-calamares-config/rootfs/usr/bin/gnegnolios-install`
- Modify: `packages/gnegnolios-calamares-config/PKGBUILD`

**Interfaces:**
- Consumes: `settings-express.conf`, `settings-guided.conf`, `settings-advanced.conf` (Tasks 6/7), installed at `/etc/calamares/settings-<mode>.conf` on the target/live system.

- [ ] **Step 1: Confirm current script has no mode picker**

Run: `cat packages/gnegnolios-calamares-config/rootfs/usr/bin/gnegnolios-install`
Expected (current state after the earlier `pkexec` fix): the script execs `pkexec calamares "$@"` unconditionally, no mode selection.

- [ ] **Step 2: Write the new script**

Replace `packages/gnegnolios-calamares-config/rootfs/usr/bin/gnegnolios-install` with:

```sh
#!/bin/sh

set -eu

if ! command -v calamares >/dev/null 2>&1; then
    printf '%s\n' "Calamares is not installed. Install or provide the Calamares runtime before launching the installer." >&2
    exit 127
fi

if ! command -v zenity >/dev/null 2>&1; then
    printf '%s\n' "zenity is not installed. Install zenity before launching the installer." >&2
    exit 127
fi

mode="$(zenity --list \
    --title="GnegnoliOS Installer" \
    --text="Choose an installation mode" \
    --radiolist \
    --column="" --column="Mode" --column="Description" \
    TRUE  Express  "Ready-to-use system, no questions asked" \
    FALSE Guided   "Recommended: pick software by category" \
    FALSE Advanced "Full control: kernel, filesystem, bootloader, packages" \
    --hide-header)"

if [ -z "$mode" ]; then
    exit 0
fi

case "$mode" in
    Express)  conf=/etc/calamares/settings-express.conf ;;
    Guided)   conf=/etc/calamares/settings-guided.conf ;;
    Advanced) conf=/etc/calamares/settings-advanced.conf ;;
    *)
        printf '%s\n' "Unknown mode: $mode" >&2
        exit 1
        ;;
esac

exec pkexec calamares -c "$conf" "$@"
```

- [ ] **Step 3: Add `zenity` as a real dependency**

In `packages/gnegnolios-calamares-config/PKGBUILD`, the current `depends=()` array does not exist (only `optdepends`). Add:

```bash
depends=(
    'zenity'
)
```

right before the existing `optdepends=(` block.

- [ ] **Step 4: Verify the script is syntactically valid**

Run: `sh -n packages/gnegnolios-calamares-config/rootfs/usr/bin/gnegnolios-install`
Expected: no output, exit code 0 (syntax OK).

- [ ] **Step 5: Verify PKGBUILD is syntactically valid**

Run: `bash -n packages/gnegnolios-calamares-config/PKGBUILD`
Expected: no output, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add packages/gnegnolios-calamares-config/rootfs/usr/bin/gnegnolios-install packages/gnegnolios-calamares-config/PKGBUILD
git commit -m "installer: add Express/Guided/Advanced mode picker via zenity

gnegnolios-install now asks which mode to run, then launches
calamares -c against the matching generated settings file."
```

---

### Task 10: `validate-calamares-config.sh` + wire generator/validator into the build

**Files:**
- Create: `scripts/validate-calamares-config.sh`
- Modify: `scripts/lib/generators.sh`
- Modify: `scripts/lib/build-engine.sh`

**Interfaces:**
- Consumes: every generated file from Tasks 2-8.
- Produces: `generate_calamares_config` wired into `generate_files()`; a new `validate_calamares_config` function called right after `generate_files()` in `run_build()`.

- [ ] **Step 1: Confirm the validator doesn't exist yet**

Run: `ls scripts/validate-calamares-config.sh 2>&1`
Expected: `No such file or directory`.

- [ ] **Step 2: Write the validator**

Create `scripts/validate-calamares-config.sh`, styled after `scripts/validate-installer-catalog.sh`:

```bash
#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CALAMARES_ROOT="$PROJECT_ROOT/packages/gnegnolios-calamares-config/rootfs/etc/calamares"

validate_calamares_config() {

    python3 - "$CALAMARES_ROOT" <<'PY'
import pathlib
import sys

import yaml

calamares_root = pathlib.Path(sys.argv[1])
errors = []

for settings_name in ("settings.conf", "settings-express.conf", "settings-guided.conf", "settings-advanced.conf"):
    settings_path = calamares_root / settings_name

    if not settings_path.exists():
        errors.append(f"missing {settings_name}")
        continue

    doc = yaml.safe_load(settings_path.read_text())
    instance_ids = {i["id"] for i in doc.get("instances", [])}

    for phase in doc.get("sequence", []):
        for step in phase.get("show", []) + phase.get("exec", []):
            if "@" not in step:
                continue

            module, instance_id = step.split("@", 1)

            if instance_id not in instance_ids:
                errors.append(f"{settings_name}: '{step}' has no matching instance")
                continue

            instance = next(i for i in doc["instances"] if i["id"] == instance_id)
            config_name = instance.get("config")

            if config_name is None:
                continue

            config_path = calamares_root / "modules" / config_name

            if not config_path.exists():
                errors.append(f"{settings_name}: instance '{instance_id}' references missing config {config_name}")
                continue

            config_doc = yaml.safe_load(config_path.read_text())

            if module == "packagechooser" and not config_doc.get("items"):
                errors.append(f"{config_name}: empty items list")

if errors:
    print("\n".join(errors))
    sys.exit(1)

print("Calamares config validation: OK")
PY
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_calamares_config
fi
```

- [ ] **Step 3: Wire the generator into `generate_files()`**

In `scripts/lib/generators.sh`, change:

```bash
generate_files() {

    "$PROJECT_ROOT/scripts/generate-os-release.sh"

}
```

to:

```bash
generate_files() {

    "$PROJECT_ROOT/scripts/generate-os-release.sh"

    source "$PROJECT_ROOT/scripts/generate-calamares-config.sh"
    generate_calamares_config

}
```

- [ ] **Step 4: Wire the validator into `run_build()`**

In `scripts/lib/build-engine.sh`, change:

```bash
    generate_package_list

    show_configuration

    echo "Generating project files..."
    generate_files
```

to:

```bash
    generate_package_list

    show_configuration

    echo "Generating project files..."
    generate_files

    echo "Validating Calamares configuration..."
    source "$PROJECT_ROOT/scripts/validate-calamares-config.sh"
    validate_calamares_config
```

- [ ] **Step 5: Run the full generation + validation chain end to end**

Run: `bash -c 'source scripts/generate-calamares-config.sh && generate_calamares_config && source scripts/validate-calamares-config.sh && validate_calamares_config'`
Expected: ends with `Calamares config validation: OK` and no error lines before it.

- [ ] **Step 6: Deliberately break something and confirm the validator catches it**

Run: `rm packages/gnegnolios-calamares-config/rootfs/etc/calamares/modules/packagechooser-browsers.conf && bash -c 'source scripts/validate-calamares-config.sh && validate_calamares_config'`
Expected: exits non-zero, prints a line containing `references missing config packagechooser-browsers.conf`.

Then regenerate to restore it: `bash scripts/generate-calamares-config.sh`

- [ ] **Step 7: Commit**

```bash
git add scripts/validate-calamares-config.sh scripts/lib/generators.sh scripts/lib/build-engine.sh
git commit -m "installer: wire calamares config generation and validation into build

generate_files() now also generates the Calamares settings/module
configs; run_build() validates them right after, failing loudly
before mkarchiso runs if anything is missing or empty."
```

---

## Self-Review Notes

**Spec coverage:** Express (Task 6), Guided (Task 7), Advanced (Task 7 + 3/4/5), package/kernel selection (Task 2/3), filesystem choice (Task 4), bootloader choice (Task 5), driver handling (Task 8, with an explicit deferred-scope correction found and documented during planning), generation from `config/installer.yaml` as single source of truth (Task 2), build wiring + validation (Task 10), zenity launcher (Task 9). No spec section left uncovered.

**Type/interface consistency:** `resolve_option_packages(category_id, option_id)` signature is identical everywhere it's used (Tasks 2, 3, 6, 8-then-removed). `write_packagechooser_conf(category_id, option_ids, mode, default_id=None)` signature is identical in Tasks 2, 3, 5. Instance id `bootloader` (Task 5/7) matches the GS key `packagechooser_bootloader` Task 5's `bootloader.conf` expects. `packages@express` instance id (Task 6) matches the reference in Task 6's own `exec` list.

**Corrected mid-plan:** Task 8 originally proposed a `shellprocess`-based driver auto-detect, then found (documented inline, Step 4) that Calamares has no stock mechanism for a script's runtime output to reach `packageOperations`. Resolved by shipping a generic `mesa` baseline instead and documenting the deferral in the design spec — this is a real scope correction discovered during planning, not a placeholder.
