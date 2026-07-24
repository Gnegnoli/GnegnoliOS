#!/bin/bash

run_build() {

    print_banner

    load_configuration

    validate_configuration

    show_configuration

    echo "Generating project files..."
    generate_files

    echo

    build_packages

    echo

    build_iso

    echo
    echo "========================================="
    echo " Build completed successfully."
    echo "========================================="

}
