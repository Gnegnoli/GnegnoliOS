#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

source "$PROJECT_ROOT/scripts/lib/config.sh"
source "$PROJECT_ROOT/scripts/lib/ui.sh"
source "$PROJECT_ROOT/scripts/lib/generators.sh"
source "$PROJECT_ROOT/scripts/lib/packages.sh"
source "$PROJECT_ROOT/scripts/lib/iso.sh"
source "$PROJECT_ROOT/scripts/lib/profile-engine.sh"
source "$PROJECT_ROOT/scripts/lib/workspace.sh"
source "$PROJECT_ROOT/scripts/lib/build-engine.sh"

run_build
