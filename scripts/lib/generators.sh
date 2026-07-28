#!/bin/bash

generate_files() {

    "$PROJECT_ROOT/scripts/generate-os-release.sh"

    source "$PROJECT_ROOT/scripts/generate-calamares-config.sh"
    generate_calamares_config

}
