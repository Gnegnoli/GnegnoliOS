#!/bin/bash

PROFILE_PACKAGES=()

add_packages_from_yaml() {

    local file="$1"

    [[ ! -f "$file" ]] && {
        echo "Missing profile: $file"
        exit 1
    }

    while IFS= read -r pkg; do

        [[ -z "$pkg" ]] && continue

        PROFILE_PACKAGES+=("$pkg")

    done < <(yq -r '.packages[]' "$file")
}

load_profile_packages() {

    local type="$1"
    local profile="$2"

    add_packages_from_yaml "$PROJECT_ROOT/profiles/${type}/${profile}.yaml"
}

load_configured_feature_profiles() {

    local profile

    while IFS= read -r profile; do

        [[ -z "$profile" ]] && continue
        [[ "$profile" = "null" ]] && continue

        load_profile_packages features "$profile"

    done < <(yq -r '.profiles[]?' "$CONFIG_FILE")
}

load_base_packages() {

    add_packages_from_yaml "$PROJECT_ROOT/profiles/base.yaml"
}

generate_package_list() {

    local outfile="$WORKSPACE/packages.x86_64"

    printf "%s\n" "${PROFILE_PACKAGES[@]}" \
        | sort -u > "$outfile"

    echo
    echo "Generated package list:"
    echo

    cat "$outfile"
}
