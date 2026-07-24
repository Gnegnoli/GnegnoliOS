#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/distro.yaml"
ARCHISO_DIR="$PROJECT_ROOT/distro/archiso"

print_banner() {
    echo "========================================="
    echo "      GnegnoliOS Build System"
    echo "========================================="
    echo
}

validate_value() {
    local value="$1"
    local field="$2"

    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "ERROR: Missing required field: $field"
        exit 1
    fi
}

load_configuration() {

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ERROR: config/distro.yaml not found!"
        exit 1
    fi

    DISTRO_NAME=$(yq '.name' "$CONFIG_FILE")
    DISTRO_VERSION=$(yq '.version' "$CONFIG_FILE")
    DEFAULT_KERNEL=$(yq '.kernel.default' "$CONFIG_FILE")
    DEFAULT_DESKTOP=$(yq '.desktop.default' "$CONFIG_FILE")
}

validate_configuration() {

    validate_value "$DISTRO_NAME" "name"
    validate_value "$DISTRO_VERSION" "version"
    validate_value "$DEFAULT_KERNEL" "kernel.default"
    validate_value "$DEFAULT_DESKTOP" "desktop.default"

}

show_configuration() {

    echo
    echo "Distribution : $DISTRO_NAME"
    echo "Version      : $DISTRO_VERSION"
    echo "Kernel       : $DEFAULT_KERNEL"
    echo "Desktop      : $DEFAULT_DESKTOP"
    echo

}

main() {

    print_banner

    load_configuration

    validate_configuration

    show_configuration

    echo "Configuration successfully loaded."

}

main
