# GnegnoliOS Calamares Plan

GnegnoliOS uses Calamares as the installer framework, but the product experience should come from GnegnoliOS-specific branding, profile selection, and package resolution.

The canonical smart installer catalog is:

```
config/installer.yaml
```

The installable package that exposes this catalog is:

```
packages/gnegnolios-installer-config/
```

The installable package that exposes the initial Calamares settings, branding, and launcher is:

```
packages/gnegnolios-calamares-config/
```

## Intended Flow

1. Show mode selection: Express, Guided, Advanced.
2. Load profile and package data from `/usr/share/gnegnolios/installer/catalog.yaml`.
3. Let the user choose profiles and optional package groups.
4. Detect hardware for GPU driver recommendations.
5. Resolve selected items by package source.
6. Hand pacman packages to the Calamares package phase.
7. Schedule Flatpak, AUR, and manual post-install tasks separately.
8. Show a clear final summary before install.

The current `settings.conf` is a first-pass install sequence. The Smart Installer page and package-operation bridge still need a custom Calamares module or a supported contextual process that can populate `packageOperations` before the `packages` module runs.

## Why This Exists

Calamares can provide module pages and package installation hooks, but GnegnoliOS needs a higher-level catalog so it can offer smart composed profiles without duplicating package lists across the UI, build profiles, and documentation.
