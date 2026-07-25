#!/bin/bash

build_iso() {

    echo
    echo "========================================="
    echo " Building ISO"
    echo "========================================="
    echo
    mkdir -p "$CACHE_DIR"
    mkdir -p "$OUTPUT_DIR"
    echo "Workspace : $WORKSPACE"
    echo "Cache     : $CACHE_DIR"
    echo "Output    : $OUTPUT_DIR"
    echo
    echo "========== packages.x86_64 =========="
    cat "$WORKSPACE/packages.x86_64"
    echo "====================================="
    echo
    echo "Cleaning previous mkarchiso cache..."
    sudo rm -rf "$CACHE_DIR"
    mkdir -p "$CACHE_DIR"
    local log_file
    log_file="$(mktemp)"
    sudo mkarchiso \
        -v \
        -w "$CACHE_DIR" \
        -o "$OUTPUT_DIR" \
        "$WORKSPACE" 2>&1 | tee "$log_file"

    if grep -q "ERROR: Hook '.*' cannot be found" "$log_file"; then
        echo
        echo "ERROR: mkinitcpio could not find required hooks (missing archiso/mkinitcpio-archiso package?)."
        echo "Refusing to ship a broken initramfs. See log above."
        rm -f "$log_file"
        return 1
    fi
    rm -f "$log_file"

    test -f "$OUTPUT_DIR"/gnegnolios-*.iso
}
