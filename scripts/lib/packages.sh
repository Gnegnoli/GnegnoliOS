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
}

configure_local_repository() {

    local package_file
    local has_packages=false

    for package_file in "$LOCAL_REPO_DIR"/*.pkg.tar*; do
        [ -f "$package_file" ] || continue
        has_packages=true
        break
    done

    if [ "$has_packages" != "true" ]; then
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

    for package_dir in "$PROJECT_ROOT"/packages/*; do

        [ -d "$package_dir" ] || continue

        manifest="$package_dir/package.yaml"
        [ -f "$manifest" ] || continue

        enabled=$(yq -r '.enabled // false' "$manifest")
        install_iso=$(yq -r '.install.iso // false' "$manifest")

        if [ "$enabled" != "true" ] || [ "$install_iso" != "true" ]; then
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

        if [ "$enabled" != "true" ]; then
            echo "Skipping $(basename "$package_dir"): disabled."
            continue
        fi

        if [ "$build" != "true" ]; then
            echo "Skipping $(basename "$package_dir"): build disabled."
            continue
        fi

        build_package "$package_dir"
        publish_package_to_local_repository "$package_dir"

    done

    configure_local_repository

}
