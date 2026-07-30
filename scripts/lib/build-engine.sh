#!/bin/bash

run_build() {

    print_banner

    load_configuration

    validate_configuration

    ( source "$PROJECT_ROOT/scripts/validate-desktop-profiles.sh" && true )

    prepare_workspace

    load_base_packages

    choose_desktop

    load_desktop_metadata

    load_profile_packages desktops "$BUILD_DESKTOP"

    PROFILE_PACKAGES+=("$DESKTOP_BRANDING_PACKAGE")

    load_profile_packages kernels "$DISTRO_KERNEL"

    load_configured_feature_profiles

    load_project_iso_packages

    generate_package_list

    show_configuration

    echo "Generating project files..."
    GNEGNOLIOS_DESKTOP="$BUILD_DESKTOP" generate_files

    write_display_manager_symlink

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
