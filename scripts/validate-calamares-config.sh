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
