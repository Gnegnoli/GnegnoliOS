#!/bin/bash

build_package() {

    local package_dir="$1"
    local package_name

    package_name=$(basename "$package_dir")

    echo "-----------------------------------------"
    echo "Building package: $package_name"
    echo "-----------------------------------------"

    (
        cd "$package_dir"

        rm -rf pkg src
        rm -f ./*.pkg.tar*

        makepkg -fs --noconfirm
    )

    echo
}

prepare_local_repository() {

    rm -rf "$LOCAL_REPO_DIR"
    mkdir -p "$LOCAL_REPO_DIR"
}

publish_package_to_local_repository() {

    local package_dir="$1"
    local package_file
    local published=false

    for package_file in "$package_dir"/*.pkg.tar*; do

        [ -f "$package_file" ] || continue

        cp "$package_file" "$LOCAL_REPO_DIR/"
        repo-add "$LOCAL_REPO_DIR/$LOCAL_REPO_NAME.db.tar.gz" \
            "$LOCAL_REPO_DIR/$(basename "$package_file")" >/dev/null

        published=true

    done

    if [ "$published" != "true" ]; then
        echo "ERROR: no package artifact generated in $package_dir"
        exit 1
    fi

    sudo pacman -U --noconfirm --needed "$package_dir"/*.pkg.tar* >/dev/null
}

configure_local_repository() {

    if grep -q "^\[$LOCAL_REPO_NAME\]" "$WORKSPACE/pacman.conf" 2>/dev/null; then
        return
    fi

    cat >> "$WORKSPACE/pacman.conf" <<EOF

[$LOCAL_REPO_NAME]
SigLevel = Optional TrustAll
Server = file://$LOCAL_REPO_DIR
EOF
}

load_project_iso_packages() {

    local package_dir
    local manifest
    local package_name
    local enabled
    local install_iso
    local package_desktop

    for package_dir in "$PROJECT_ROOT"/packages/*; do

        [ -d "$package_dir" ] || continue

        manifest="$package_dir/package.yaml"
        [ -f "$manifest" ] || continue

        enabled=$(yq -r '.enabled // false' "$manifest")
        install_iso=$(yq -r '.install.iso // false' "$manifest")
        package_desktop=$(yq -r '.desktop // ""' "$manifest")

        if [ "$enabled" != "true" ] || [ "$install_iso" != "true" ]; then
            continue
        fi

        if [ -n "$package_desktop" ] && [ "$package_desktop" != "null" ] && [ "$package_desktop" != "$BUILD_DESKTOP" ]; then
            continue
        fi

        package_name=$(yq -r '.name // ""' "$manifest")

        if [ -z "$package_name" ] || [ "$package_name" = "null" ]; then
            echo "ERROR: missing package name in $manifest"
            exit 1
        fi

        PROFILE_PACKAGES+=("$package_name")

    done
}

build_packages() {

    echo "Searching for packages..."
    echo

    prepare_local_repository
    configure_local_repository

    for package_dir in "$PROJECT_ROOT"/packages/*; do

        [ -d "$package_dir" ] || continue

        if [ ! -f "$package_dir/package.yaml" ]; then
            echo "Skipping $(basename "$package_dir"): package.yaml not found."
            continue
        fi

        if [ ! -f "$package_dir/PKGBUILD" ]; then
            echo "Skipping $(basename "$package_dir"): PKGBUILD not found."
            continue
        fi

        enabled=$(yq '.enabled' "$package_dir/package.yaml")
        build=$(yq '.build' "$package_dir/package.yaml")
        package_desktop=$(yq -r '.desktop // ""' "$package_dir/package.yaml")

        if [ "$enabled" != "true" ]; then
            echo "Skipping $(basename "$package_dir"): disabled."
            continue
        fi

        if [ "$build" != "true" ]; then
            echo "Skipping $(basename "$package_dir"): build disabled."
            continue
        fi

        if [ -n "$package_desktop" ] && [ "$package_desktop" != "null" ] && [ "$package_desktop" != "$BUILD_DESKTOP" ]; then
            echo "Skipping $(basename "$package_dir"): built for desktop '$package_desktop', not '$BUILD_DESKTOP'."
            continue
        fi

        build_package "$package_dir"
        publish_package_to_local_repository "$package_dir"

    done

}
