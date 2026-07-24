#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/distro.yaml"
ARCHISO_DIR="$PROJECT_ROOT/distro/archiso"

source "$PROJECT_ROOT/scripts/lib/config.sh"

print_banner() {

    echo "========================================="
    echo "      GnegnoliOS Build System"
    echo "========================================="
    echo

}

show_configuration() {

    echo "Distribution : $DISTRO_NAME"
    echo "Version      : $DISTRO_VERSION"
    echo "Kernel       : $DEFAULT_KERNEL"
    echo "Desktop      : $DEFAULT_DESKTOP"
    echo

}

generate_files() {

    echo "Generating project files..."

    "$PROJECT_ROOT/scripts/generate-os-release.sh"

    echo

}

main() {

    print_banner

    load_configuration

    validate_configuration

    show_configuration

    generate_files

    echo "Build preparation completed successfully."

}

main
