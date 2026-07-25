#!/bin/bash

WORKSPACE="$PROJECT_ROOT/build/profile"
CACHE_DIR="$PROJECT_ROOT/build/cache"
OUTPUT_DIR="$PROJECT_ROOT/build/output"
LOCAL_REPO_NAME="gnegnolios-local"
LOCAL_REPO_DIR="$PROJECT_ROOT/build/repository"

prepare_workspace() {

    echo
    echo "Preparing build workspace..."

    rm -rf "$WORKSPACE"

    mkdir -p "$WORKSPACE"

    cp -a "$PROJECT_ROOT/distro/archiso/." "$WORKSPACE"

}
