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

load_desktop_metadata() {

    local file="$PROJECT_ROOT/profiles/desktops/${BUILD_DESKTOP}.yaml"

    [[ ! -f "$file" ]] && {
        echo "Missing profile: $file"
        exit 1
    }

    DESKTOP_STATUS=$(yq -r '.status' "$file")
    DESKTOP_DISPLAY_MANAGER_PACKAGE=$(yq -r '.display_manager.package' "$file")
    DESKTOP_DISPLAY_MANAGER_SERVICE=$(yq -r '.display_manager.service' "$file")
    DESKTOP_SESSION=$(yq -r '.session' "$file")
    DESKTOP_BRANDING_PACKAGE=$(yq -r '.branding_package' "$file")
    DESKTOP_DEFAULT_TERMINAL=$(yq -r '.defaults.terminal' "$file")
    DESKTOP_DEFAULT_FILE_MANAGER=$(yq -r '.defaults.file_manager' "$file")
    DESKTOP_DEFAULT_EDITOR=$(yq -r '.defaults.editor' "$file")
    DESKTOP_DEFAULT_SCREENSHOT=$(yq -r '.defaults.screenshot' "$file")

    if [[ "$DESKTOP_STATUS" == "experimental" ]]; then
        echo
        echo "WARNING: desktop profile '$BUILD_DESKTOP' is marked experimental."
        echo "Arch/AUR packaging maturity for this desktop is inconsistent. Build proceeds."
        echo
    fi
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
