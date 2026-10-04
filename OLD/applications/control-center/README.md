# Gnegnoli Control Center

PyQt6 desktop app for GnegnoliOS: sidebar navigation + a `QStackedWidget`
content area, live system stats on the dashboard, and real system actions
(pacman, flatpak, docker, snapper, cpupower, wine, lutris, ...) wired to
buttons across every section.

## Layout

- `main.py` — entry point
- `window.py` — main window: sidebar (icons, collapsible Gaming/Software
  groups) + `QStackedWidget`
- `theme.py` — color palette and global QSS (dark theme, red accent)
- `widgets.py` — reusable widgets: `Card`, `Gauge` (performance dial),
  `Sparkline` (rolling usage graph), `info_row`, `status_row`
- `icons.py` — loads bundled SVG icons and recolors them at runtime
- `commands.py` — runs real system commands via `QProcess` (async, doesn't
  block the UI); see below
- `sysinfo.py` — fast read-only host info (CPU/GPU/motherboard/OS/uptime,
  package/service checks) for the dashboard
- `pages/dashboard.py` — the dashboard page
- `pages/stub.py` — every other sidebar page (`StubPage` base + one class per
  section), each with a `(label, handler)` action list and a live output
  console
- `assets/icons/` — bundled Lucide icons (ISC license), offline, no network
  calls at runtime

## How actions are wired

Every button's handler returns either:

- `(argv: list[str], needs_root: bool)` — run via `commands.run_or_notify`.
  `needs_root=True` prefixes the command with `pkexec`.
- `None` — pops up "Not available" (used only when there's no single command
  that would make sense to run, e.g. a feature that needs a picker UI that
  doesn't exist yet).

`commands.run` uses `QProcess` instead of blocking `subprocess.run`, since
long-running commands (`pacman -Syu`, etc.) would otherwise freeze the GUI.

**Missing binary handling**: if a command fails to start because the binary
isn't installed, the app asks "`<binary>` isn't installed. Install package
`<name>` now?" (Yes/No) and runs `pacman -S <name> --noconfirm` via `pkexec`
if you say yes. A binary→package name map lives in
`commands.BINARY_TO_PACKAGE` for the handful of cases where they differ
(`winecfg` → `wine`, `gnome-disks` → `gnome-disk-utility`, etc.) — anything
not listed falls back to the binary's own name.

This only fires for binaries the app actually tries to run — a few actions
(AUR helper `yay`/`paru`, "Driver Manager", "Set Default Kernel", ...) have no
single official package that would fix them, so they show the plain "Not
available" popup instead.

## Running it during development

```bash
sudo pacman -Syu
sudo pacman -S python-pyqt6 python-psutil qt6-svg pacman-contrib polkit
python3 main.py
```

`qt6-svg` is required for the bundled icons (`PyQt6.QtSvg`). `pacman-contrib`
provides `checkupdates` (used for "Check pacman Updates" without touching the
system db). `polkit` provides `pkexec` for root actions — needs a running
polkit authentication agent (already part of a normal desktop session).

## Packaging

The app is packaged as `gnegnolios-control-center`
(`packages/gnegnolios-control-center/`), which installs a launcher at
`/usr/bin/gnegnoli-control-center` and a `.desktop` entry so it always shows
up in the application menu — no manual launch needed on an installed system.
See that package's README for details.

## What's intentionally not implemented yet

Package/repo pickers (Install/Remove Packages, Add Repo), some
selection-dependent actions (Remove Proton Version, Restore Snapshot,
Controller Setup, MangoHud Toggle, Set Default Kernel/Proton, theming
pages) — these need a UI beyond a single button and currently show "Not
available".
