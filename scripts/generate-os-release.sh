#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$PROJECT_ROOT/config/distro.yaml"
OUTPUT_DIR="$PROJECT_ROOT/packages/gnegnolios-release"

NAME=$(yq '.name' "$CONFIG_FILE")
VERSION=$(yq '.version' "$CONFIG_FILE")
ID=$(yq '.id' "$CONFIG_FILE")

cat > "$OUTPUT_DIR/os-release" <<EOF
NAME="$NAME"
PRETTY_NAME="$NAME $VERSION"
ID=$ID
ID_LIKE=arch
VERSION="$VERSION"
VERSION_ID="$VERSION"
HOME_URL="https://gnegnolios.org"
SUPPORT_URL="https://github.com/GnegnoliOS"
BUG_REPORT_URL="https://github.com/GnegnoliOS"
EOF

cp "$OUTPUT_DIR/os-release" "$OUTPUT_DIR/os-release.etc"

echo "Generated os-release successfully."
