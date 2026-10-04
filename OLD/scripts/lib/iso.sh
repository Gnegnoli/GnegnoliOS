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

    local log_file="$LOG_DIR/mkarchiso.log"
    local mkarchiso_status

    echo -n "Running mkarchiso... "

    if sudo env LC_ALL=C mkarchiso \
        -v \
        -w "$CACHE_DIR" \
        -o "$OUTPUT_DIR" \
        "$WORKSPACE" >"$log_file" 2>&1; then
        mkarchiso_status=0
    else
        mkarchiso_status=$?
    fi

    if grep -q "ERROR: Hook '.*' cannot be found" "$log_file"; then
        echo "FAILED"
        echo
        echo "ERROR: mkinitcpio could not find required hooks (missing archiso/mkinitcpio-archiso package?)."
        echo "Refusing to ship a broken initramfs."
        tail -n 50 "$log_file"
        echo
        echo "Full log: $log_file"
        return 1
    fi

    if [ "$mkarchiso_status" -ne 0 ]; then
        echo "FAILED"
        echo
        tail -n 50 "$log_file"
        echo
        echo "ERROR: mkarchiso exited with status $mkarchiso_status."
        echo "Full log: $log_file"
        return 1
    fi

    echo "OK"

    compgen -G "$OUTPUT_DIR/gnegnolios-*.iso" >/dev/null
}
