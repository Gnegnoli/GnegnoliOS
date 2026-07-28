#!/bin/bash

run_build() {

    print_banner

    load_configuration

    validate_configuration

    prepare_workspace

    load_base_packages

    choose_desktop

    load_profile_packages desktops "$BUILD_DESKTOP"

    load_profile_packages kernels "$DISTRO_KERNEL"

    load_configured_feature_profiles

    load_project_iso_packages

    generate_package_list

    show_configuration

    echo "Generating project files..."
    generate_files

    echo "Validating Calamares configuration..."
    ( source "$PROJECT_ROOT/scripts/validate-calamares-config.sh" && validate_calamares_config )

    echo

    build_packages

    echo

    build_iso

    echo
    echo "========================================="
    echo " Build completed successfully."
    echo "========================================="
}
