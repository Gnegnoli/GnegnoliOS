#!/bin/bash

set -e

echo "========================================="
echo "      GnegnoliOS Build System"
echo "========================================="
echo

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/distro.yaml"
ARCHISO_DIR="$PROJECT_ROOT/distro/archiso"

echo "Checking configuration..."

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: config/distro.yaml not found!"
    exit 1
fi

DISTRO_NAME=$(yq '.name' "$CONFIG_FILE")
DISTRO_VERSION=$(yq '.version' "$CONFIG_FILE")
DEFAULT_KERNEL=$(yq '.kernel.default' "$CONFIG_FILE")
DEFAULT_DESKTOP=$(yq '.desktop.default' "$CONFIG_FILE")
validate_value() {
    local value="$1"
    local field="$2"

    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "ERROR: Missing required field: $field"
        exit 1
    fi
}

validate_value "$DISTRO_NAME" "name"
validate_value "$DISTRO_VERSION" "version"
validate_value "$DEFAULT_KERNEL" "kernel.default"
validate_value "$DEFAULT_DESKTOP" "desktop.default"
echo
echo "Distribution : $DISTRO_NAME"
echo "Version      : $DISTRO_VERSION"
echo "Kernel       : $DEFAULT_KERNEL"
echo "Desktop      : $DEFAULT_DESKTOP"

echo
echo "Configuration successfully loaded."
