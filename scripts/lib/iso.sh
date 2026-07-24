#!/bin/bash

build_iso() {

    echo
    echo "========================================="
    echo " Building ISO"
    echo "========================================="
    echo

    local profile="$PROJECT_ROOT/distro/archiso"
    local output="$PROJECT_ROOT/out"
    local work="$PROJECT_ROOT/work"

    mkdir -p "$output"

    sudo mkarchiso \
        -v \
        -w "$work" \
        -o "$output" \
        "$profile"

}
