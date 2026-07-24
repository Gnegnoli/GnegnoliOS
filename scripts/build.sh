#!/bin/bash

set -e

echo "========================================="
echo "      GnegnoliOS Build System"
echo "========================================="
echo

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHISO_DIR="$PROJECT_ROOT/distro/archiso"

echo "Project root : $PROJECT_ROOT"
echo "ArchISO path : $ARCHISO_DIR"

echo
echo "Build system initialized."

