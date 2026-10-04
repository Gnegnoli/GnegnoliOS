# GnegnoliOS Architecture

## Philosophy

GnegnoliOS is built around a single source of truth.

Every component of the distribution should derive its configuration from the distribution manifest whenever possible.

The project favors automation over duplicated configuration.

---

# Repository Layout

```
GnegnoliOS/

applications/
assets/
branding/
calamares/
config/
docs/
distro/
packages/
scripts/
```

---

# Directory Responsibilities

## applications/

Applications developed specifically for GnegnoliOS.

Examples:

- Control Center
- Welcome App
- Driver Manager
- Update Manager

---

## assets/

Generic project resources.

Examples:

- Icons
- Images
- Screenshots

---

## branding/

Distribution branding.

Examples:

- Wallpapers
- Logos
- Plymouth theme
- GRUB theme
- SDDM theme

---

## calamares/

Installer configuration.

Contains:

- Modules
- Branding
- Installer configuration

The Smart Installer must read `config/installer.yaml` through the installed `gnegnolios-installer-config` package instead of duplicating profile data in Calamares module files.

---

## config/

Global distribution configuration.

Main file:

```
distro.yaml
```

This is the main configuration file of the project.

Additional catalog:

```
installer.yaml
```

This file describes Smart Installer modes, profile categories, package groups, and package sources.

---

## distro/

Everything required to generate the ISO.

Contains:

- ArchISO profile
- ISO generation resources

---

## packages/

Packages developed for GnegnoliOS.

Examples:

- gnegnolios-release
- gnegnolios-defaults
- gnegnolios-branding
- gnegnolios-installer-config
- gnegnolios-calamares-config

Packages with `enabled: true` and `install.iso: true` in `package.yaml` are added to the generated ArchISO package list. During the build, package artifacts are published to a generated local pacman repository and the workspace `pacman.conf` is extended with that repository.

---

## scripts/

Build tools.

Examples:

- build.sh
- clean.sh
- release.sh

---

## docs/

Project documentation.

Everything related to architecture and development should be documented here.

---

# Development Principles

- One responsibility per script.
- One responsibility per package.
- Configuration before code.
- Automation whenever possible.
- Never duplicate configuration.
- Every new feature must be documented.
