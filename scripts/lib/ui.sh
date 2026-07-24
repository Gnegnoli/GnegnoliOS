#!/bin/bash

print_banner() {

    clear

    echo "================================================="
    echo "               GnegnoliOS Builder"
    echo "================================================="
    echo
}

choose_desktop() {

    local desktops=()

    for file in "$PROJECT_ROOT"/profiles/desktops/*.yaml; do
        desktops+=("$(basename "$file" .yaml)")
    done

    echo
    echo "Select Desktop Environment"
    echo "--------------------------"

    select choice in "${desktops[@]}"; do

        if [[ -n "$choice" ]]; then
            BUILD_DESKTOP="$choice"
            break
        fi

        echo "Invalid selection."

    done

    echo
    echo "Selected desktop: $BUILD_DESKTOP"
    echo
}

show_configuration() {

    echo "Distribution : $DISTRO_NAME"
    echo "Version      : $DISTRO_VERSION"
    echo "Kernel       : $DISTRO_KERNEL"
    echo "Desktop      : $DISTRO_DESKTOP"
    echo
}
