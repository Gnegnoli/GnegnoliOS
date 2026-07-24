#!/bin/bash

set -e

echo "========================================="
echo "      GnegnoliOS Build System"
echo "========================================="
echo

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/distro.yaml"
ARCHISO_DIR="$PROJECT_ROOT/distro/archiso"

echo "Project root : $PROJECT_ROOT"
echo "Config file  : $CONFIG_FILE"
echo "ArchISO path : $ARCHISO_DIR"
echo

echo "Checking configuration..."

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: config/distro.yaml not found!"
    exit 1
fi

echo "Configuration OK."
echo
echo "Build system initialized."
