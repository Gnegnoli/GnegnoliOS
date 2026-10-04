#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python - "$PROJECT_ROOT" <<'PY'
import pathlib
import sys

import yaml

root = pathlib.Path(sys.argv[1])
errors = []

REQUIRED_TOP = ["id", "name", "status", "packages", "display_manager", "session", "defaults", "branding_package"]
REQUIRED_DM = ["package", "service"]
REQUIRED_DEFAULTS = ["terminal", "file_manager", "editor", "screenshot"]
VALID_STATUS = {"stable", "experimental"}

for profile_file in sorted((root / "profiles/desktops").glob("*.yaml")):
    profile = yaml.safe_load(profile_file.read_text()) or {}
    name = profile_file.name

    for field in REQUIRED_TOP:
        if field not in profile:
            errors.append(f"{name}: missing required field '{field}'")

    if "status" in profile and profile["status"] not in VALID_STATUS:
        errors.append(f"{name}: status must be one of {sorted(VALID_STATUS)}, got '{profile['status']}'")

    if "display_manager" in profile:
        for field in REQUIRED_DM:
            if field not in profile["display_manager"]:
                errors.append(f"{name}: display_manager missing required field '{field}'")

    if "defaults" in profile:
        for field in REQUIRED_DEFAULTS:
            if field not in profile["defaults"]:
                errors.append(f"{name}: defaults missing required field '{field}'")

if errors:
    print("Desktop profile validation failed:")
    for error in errors:
        print(f"  - {error}")
    sys.exit(1)

print(f"All desktop profiles valid.")
PY
