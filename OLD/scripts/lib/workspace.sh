#!/bin/bash

WORKSPACE="$PROJECT_ROOT/build/profile"
CACHE_DIR="$PROJECT_ROOT/build/cache"
OUTPUT_DIR="$PROJECT_ROOT/build/output"
LOG_DIR="$PROJECT_ROOT/build/logs"
LOCAL_REPO_NAME="gnegnolios-local"
LOCAL_REPO_DIR="$PROJECT_ROOT/build/repository"

prepare_workspace() {

    echo
    echo "Preparing build workspace..."

    rm -rf "$WORKSPACE"

    mkdir -p "$WORKSPACE"
    mkdir -p "$LOG_DIR"

    cp -a "$PROJECT_ROOT/distro/archiso/." "$WORKSPACE"

}

write_display_manager_symlink() {

    local dm_dir="$WORKSPACE/airootfs/etc/systemd/system"

    mkdir -p "$dm_dir"

    ln -sf "/usr/lib/systemd/system/${DESKTOP_DISPLAY_MANAGER_SERVICE}.service" \
        "$dm_dir/display-manager.service"

    echo "Live ISO display manager: ${DESKTOP_DISPLAY_MANAGER_SERVICE}"
}
