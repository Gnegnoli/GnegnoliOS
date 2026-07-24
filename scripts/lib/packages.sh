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

        makepkg -f --noconfirm
    )

    echo
}

build_packages() {

    echo "Searching for packages..."
    echo

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

        if [ "$enabled" != "true" ]; then
            echo "Skipping $(basename "$package_dir"): disabled."
            continue
        fi

        build_package "$package_dir"

    done

}
