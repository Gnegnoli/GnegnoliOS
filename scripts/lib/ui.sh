#!/bin/bash

print_banner() {

    echo "========================================="
    echo "      GnegnoliOS Build System"
    echo "========================================="
    echo
}

show_configuration() {

    echo "Distribution : $DISTRO_NAME"
    echo "Version      : $DISTRO_VERSION"
    echo "Kernel       : $DISTRO_KERNEL"
    echo "Desktop      : $DISTRO_DESKTOP"
    echo
}
