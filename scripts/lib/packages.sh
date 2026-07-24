#!/bin/bash

build_package() {

    local package_name="$1"
    local package_dir="$PROJECT_ROOT/packages/$package_name"

    if [ ! -d "$package_dir" ]; then
        echo "ERROR: Package '$package_name' not found."
        exit 1
    fi

    echo "Building package: $package_name"

    (
        cd "$package_dir"

        rm -rf pkg src

        makepkg -f --noconfirm
    )

    echo "Package '$package_name' built successfully."
    echo
}

build_packages() {

    build_package "gnegnolios-release"

}
