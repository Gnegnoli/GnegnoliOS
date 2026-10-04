# GnegnoliOS Smart Installer

## Philosophy

The installer must be simple for a beginner and powerful for an advanced user.

Core promise:

> Install only what you need. Everything works. Nothing is missing.

The installer is based on Calamares, but GnegnoliOS should treat Calamares as the host framework, not as the whole product experience. The distinctive layer is a smart catalog of profiles, package groups, and install modes.

## Install Modes

### Express Installation

Express is for users who want to install and use the computer immediately. It should ask no software-selection questions and install a complete KDE Plasma system with Firefox, LibreOffice, VLC, GIMP, Steam, Flatpak, PipeWire, drivers, codecs, snapshots, UFW, and base tools.

### Guided Installation

Guided is the recommended mode. It should present high-level usage profiles first, then allow category-level refinement.

### Advanced Installation

Advanced unlocks filesystem, kernel, bootloader, services, package sources, and granular software choices.

## Interface Model

Avoid a long wizard made of many checkbox-only pages. Use expandable category cards instead:

- Each category has a short description.
- Each category shows how many packages it includes.
- Beginners can select a whole profile with one click.
- Advanced users can expand a category and override individual components.
- The final page shows a clear summary and lets the user go back to edit any choice.

## Catalog

The canonical installer data lives in:

```
config/installer.yaml
```

That catalog separates packages by source:

- `pacman` for official repositories and custom repos available during install.
- `aur` for packages that require the configured AUR helper.
- `flatpak` for app sandbox installs.
- `manual` for software that cannot be redistributed directly or needs vendor-specific handling.
- `hardware_optional` for GPU-dependent stacks such as CUDA or ROCm.

This separation matters because the ISO package list can only include packages resolvable by pacman at build time.

## Profiles

The first smart profiles are:

- Home
- Office
- Gaming
- Streaming
- Development
- Music Production
- Graphic Design
- Video Editing
- Photography
- 3D Modeling
- CAD
- Cybersecurity
- Virtualization
- Server
- AI And Machine Learning

Composite profiles should sit above those blocks:

- Creator Edition
- Developer Edition
- Gamer Edition
- Enterprise Edition

## Implementation Notes

The current repository now has two profile layers:

- `profiles/features/*.yaml` contains build-safe pacman package groups.
- `config/installer.yaml` contains the full smart installer catalog, including AUR, Flatpak, manual, and hardware-conditional packages.

Future Calamares work should add a custom module or module sequence that reads the catalog, stores selected choices, resolves packages by source, then hands pacman packages to Calamares' package installation phase and schedules AUR/Flatpak/manual steps safely after the base system is installed.

The first resolver CLI is installed by `gnegnolios-installer-config`:

```
gnegnolios-installer-resolve --mode express
gnegnolios-installer-resolve --profile development --choice browsers=firefox
```

It outputs a structured package plan split by `pacman`, `aur`, `flatpak`, and `manual`, which is the expected bridge between the future UI and Calamares execution.

Catalog consistency can be checked with:

```
scripts/validate-installer-catalog.sh
```
