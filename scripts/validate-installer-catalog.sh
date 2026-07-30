#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python - "$PROJECT_ROOT" <<'PY'
import pathlib
import subprocess
import sys

import yaml

root = pathlib.Path(sys.argv[1])
catalog = yaml.safe_load((root / "config/installer.yaml").read_text())
errors = []
allowed_sources = {"pacman", "aur", "flatpak", "manual", "hardware_optional"}

profiles = set(catalog.get("profiles", {}))
groups = catalog.get("package_groups", {})
project_packages = {
    yaml.safe_load((package_dir / "package.yaml").read_text()).get("name")
    for package_dir in (root / "packages").iterdir()
    if (package_dir / "package.yaml").exists()
}
project_packages.discard(None)


def collect_pacman_packages(package_map):
    packages = set(package_map.get("pacman", []))

    for optional_packages in package_map.get("hardware_optional", {}).values():
        packages.update(optional_packages)

    return packages


def check_package_map(context, package_map):
    for source in package_map:
        if source not in allowed_sources:
            errors.append(f"{context}: unknown package source '{source}'")


for category in catalog.get("categories", []):
    category_id = category.get("id")

    for option in category.get("options", []):
        if category_id == "usage_profiles":
            if option not in profiles:
                errors.append(f"Missing profile for usage option: {option}")
            continue

        if category_id not in groups:
            errors.append(f"Missing package group: {category_id}")
            break

        if option not in groups[category_id]:
            errors.append(f"Missing option {option} in package group {category_id}")


for edition, data in catalog.get("composed_profiles", {}).items():
    for include in data.get("includes", []):
        if include not in profiles:
            errors.append(f"Missing composed profile include {include} in {edition}")


for profile, data in catalog.get("profiles", {}).items():
    check_package_map(f"profile {profile}", data.get("packages", {}))


for group_name, options in groups.items():
    for option, data in options.items():
        check_package_map(f"group {group_name}.{option}", data.get("packages", {}))


available = set()
try:
    output = subprocess.run(
        ["pacman", "-Sl", "core", "extra", "multilib"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    ).stdout

    for line in output.splitlines():
        parts = line.split()
        if len(parts) >= 2:
            available.add(parts[1])
except (FileNotFoundError, subprocess.CalledProcessError):
    available = set()


if available:
    profile_files = [root / "profiles/base.yaml"]
    profile_files.extend(sorted((root / "profiles/features").glob("*.yaml")))
    profile_files.extend(sorted((root / "profiles/kernels").glob("*.yaml")))

    for profile_file in profile_files:
        data = yaml.safe_load(profile_file.read_text())
        for package in data.get("packages", []):
            if package not in available and package not in project_packages:
                errors.append(f"{profile_file.relative_to(root)}: pacman package not found: {package}")

    for profile, data in catalog.get("profiles", {}).items():
        for package in collect_pacman_packages(data.get("packages", {})):
            if package not in available and package not in project_packages:
                errors.append(f"catalog profile {profile}: pacman package not found: {package}")

    for group_name, options in groups.items():
        for option, data in options.items():
            for package in collect_pacman_packages(data.get("packages", {})):
                if package not in available and package not in project_packages:
                    errors.append(
                        f"catalog group {group_name}.{option}: pacman package not found: {package}"
                    )


for profile_file in sorted((root / "profiles/desktops").glob("*.yaml")):
    desktop = yaml.safe_load(profile_file.read_text()) or {}
    desktop_defaults = desktop.get("defaults", {})

    terminal_default = desktop_defaults.get("terminal")
    if terminal_default and terminal_default not in groups.get("terminals", {}):
        errors.append(f"{profile_file.name}: defaults.terminal '{terminal_default}' is not a terminals package_group option")

    editor_default = desktop_defaults.get("editor")
    if editor_default and editor_default not in groups.get("editors", {}):
        errors.append(f"{profile_file.name}: defaults.editor '{editor_default}' is not an editors package_group option")


if errors:
    print("\n".join(errors))
    sys.exit(1)

print("Installer catalog validation: OK")
PY
