# Smart Installer — Calamares Package/Kernel/Filesystem/Bootloader Selection

## Problem

`config/installer.yaml` already describes a Smart Installer catalog (Express / Guided / Advanced modes, package categories, profiles). Nothing consumes it. Calamares (`gnegnolios-calamares-config`) ships a `settings.conf` whose `packages` module has `operations: []` with a comment saying a future module will populate it. There is no package selection UI, no kernel choice, no filesystem choice, no bootloader choice.

## Goal

Make the three modes real:

- **Express** — zero extra pages. Everything from `installer.yaml`'s `fixed_choices` / `include_profiles`.
- **Guided** — one wizard page per package category (browser, office, multimedia, dev languages, containers, virtualization, optional services, privacy, extra tools, snapshots, shells, terminals, editors, themes), plus automatic driver detection. Kernel, filesystem, and bootloader are fixed defaults (no pages).
- **Advanced** — everything Guided has, plus kernel multi-select, filesystem choice, bootloader choice, and manual driver choice.

## Constraints (verified against Calamares 3.4.x source, not assumed)

- Calamares has **no native conditional page-skip**. A `sequence:` is a static list parsed once at startup. This is why Express needs its own settings file rather than "the same wizard with defaults pre-filled."
- `packagechooser` (`method: packages`) writes to GlobalStorage key `packageOperations`; the `packages` module automatically appends whatever is in that key to its own `operations:` list. No manual wiring needed per instance.
- Multiple `packagechooser` instances can coexist in one sequence via Calamares' `instances:` mechanism (`{module, id, config, weight}`), referenced in `sequence:` as `packagechooser@<id>`.
- `partition.conf`'s `availableFileSystemTypes: [...]` natively renders a filesystem dropdown on the automatic/erase-disk partitioning page. `defaultFileSystemType` is read once from the config file, not from GlobalStorage — so Guided/Express must use a `partition.conf` that omits `availableFileSystemTypes` (fixed fs, no dropdown), while Advanced uses a `partition-advanced.conf` (via instance `config:` override) that sets it.
- `bootloader.conf` supports `efiBootLoaderVar: "<gsKey>"` — if that GlobalStorage key is set (by an earlier `packagechooser@bootloader`, `method: legacy`, single-select grub/systemd-boot), its value overrides the static `efiBootLoader` default. Native, no custom module.
- Installing multiple kernels is just listing multiple kernel packages in one `packageOperations` entry; mkinitcpio pacman hooks and `grub-mkconfig`/`kernel-install` (already in the exec sequence) pick up every installed kernel automatically.

None of the above requires a custom Calamares C++/QML module. All of it is config generation.

## Architecture

```
config/installer.yaml  (single source of truth, unchanged structure)
        │
        ▼
scripts/generate-calamares-config.sh   (new, called from generate_files())
        │  reads categories/profiles/package_groups via yq
        ▼
packages/gnegnolios-calamares-config/rootfs/etc/calamares/
        ├── settings-express.conf     (generated)
        ├── settings-guided.conf      (generated)
        ├── settings-advanced.conf    (generated)
        ├── modules/
        │     ├── packagechooser-<category>.conf   (generated, one per category)
        │     ├── packagechooser-kernel.conf        (generated, Advanced only)
        │     ├── packagechooser-bootloader.conf     (generated, Advanced only)
        │     ├── packagechooser-drivers.conf        (generated, Advanced manual driver choice)
        │     ├── partition.conf                     (generated: fixed fs, Guided/Express)
        │     ├── partition-advanced.conf             (generated: availableFileSystemTypes, Advanced)
        │     └── bootloader.conf                    (generated: efiBootLoaderVar wired in)
        └── ... (existing hand-written branding.desc, show.qml, stylesheet.qss — untouched)
        │
        ▼
build_packages()  (existing, unchanged) → makepkg builds gnegnolios-calamares-config
        │
        ▼
/usr/bin/gnegnolios-install  (modified)
        1. zenity --list  → user picks Express / Guided / Advanced
        2. exec pkexec calamares -c /etc/calamares/settings-<mode>.conf
```

Generated files under `rootfs/etc/calamares/` are build artifacts, not committed — `.gitignore` gets entries for the generated paths. Hand-authored files in the same tree (`branding.desc`, `show.qml`, `stylesheet.qss`, `modules/packages.conf`, `modules/unpackfs.conf`) are untouched by the generator and stay committed as-is.

## Components

### `scripts/generate-calamares-config.sh`

New script, sourced/called from `generate_files()` in `scripts/lib/generators.sh` (currently only calls `generate-os-release.sh`). Responsibilities:

1. Read `config/installer.yaml` via `yq`.
2. For each entry in `categories:` (excluding `filesystems`, `kernels`, `drivers`, which get special handling), emit `packagechooser-<id>.conf`: `mode: required` if `selection: single`, `mode: optionalmultiple` if `selection: multiple`; `items:` built from `package_groups.<category>.<option>` (each option's `packages.pacman`/`aur`/`flatpak` lists become that item's `packages:`); `default:` from `defaults.<field>` when the category maps to a `defaults` key (browser, office_suite, etc.).
3. Emit `packagechooser-kernel.conf` (`optionalmultiple`, items from `package_groups.kernels`, default from `defaults.kernel`).
4. Emit `packagechooser-bootloader.conf` (`required`, `method: legacy`, two items `grub`/`systemd-boot`, default `grub`).
5. Emit `packagechooser-drivers.conf` for manual Advanced driver choice (items from `package_groups.drivers`, excluding `auto-detect`).
6. Emit `partition.conf` (fixed `defaultFileSystemType` from `defaults.filesystem`, no `availableFileSystemTypes`) and `partition-advanced.conf` (same default, plus `availableFileSystemTypes` from the `filesystems` category's `options:`).
7. Emit `bootloader.conf` with `efiBootLoaderVar: packagechooser_bootloader` (matches the GS key that `packagechooser-bootloader.conf`'s legacy method writes).
8. Emit `settings-express.conf`: `sequence` has only `welcome, locale, keyboard, partition, users, summary` (show) / `partition, mount, unpackfs, machineid, fstab, locale, keyboard, localecfg, users, displaymanager, networkcfg, hwclock, services-systemd, driver-autodetect, packages, initcpio, grubcfg, bootloader, umount` (exec) — no `packagechooser@*` anywhere; `packages.conf`'s static `operations:` gets the full `include_profiles` package list plus `fixed_choices` (browser/office/etc.) baked in directly (no GS needed since nothing is user-chosen).
9. Emit `settings-guided.conf`: same as Express's exec list but with `show:` including one `packagechooser@<category>` page per category (using the Guided `categories:` list from `installer.yaml`, in that order), plus `driver-autodetect` shellprocess in exec (no bootloader/kernel/filesystem chooser pages — `partition.conf` and `bootloader.conf` without `efiBootLoaderVar` override, i.e. plain defaults).
10. Emit `settings-advanced.conf`: Guided's pages plus `packagechooser@kernel`, `packagechooser@drivers` (instead of `driver-autodetect`), `packagechooser@bootloader`; `partition` instance's `config:` set to `partition-advanced.conf`; `bootloader.conf` has `efiBootLoaderVar` set.

Fails loudly (matches `add_packages_from_yaml`'s style) if any category resolves to zero items.

### Driver auto-detect (`shellprocess`, exec phase)

New small script (e.g. `packages/gnegnolios-calamares-config/rootfs/usr/share/gnegnolios/installer/detect-drivers.sh`, hand-written, not generated) run via a `shellprocess` job before `packages` in Guided's exec sequence. Uses `lspci` to detect GPU vendor, writes the matching driver package list directly into Calamares' `packageOperations` GlobalStorage key (same mechanism `packagechooser` uses) via `calamares-python` or a `contextualprocess` helper — exact GS-write mechanism is an implementation detail for the plan, not the design.

### `/usr/bin/gnegnolios-install`

Modified (hand-written, already exists): before `pkexec calamares`, run `zenity --list --radiolist` with three rows (Express/Guided/Advanced), map the selection to `/etc/calamares/settings-<mode>.conf`, `exec pkexec calamares -c "$conf"`. If `zenity` is missing, fail with the same clear stderr pattern the script already uses for missing `calamares`.

New dependency: `zenity`, added to `depends` in `gnegnolios-calamares-config`'s `PKGBUILD` (currently has none — only `optdepends`).

### `scripts/validate-calamares-config.sh`

New, styled after the existing `scripts/validate-installer-catalog.sh`. Runs after generation, before `build_packages()`. Checks: every `packagechooser@*` id referenced in each generated `settings-*.conf`'s `sequence:` has a matching `modules/packagechooser-*.conf` file, and that file's `items:` is non-empty. Exits non-zero with a clear message otherwise (build must fail, not ship a broken installer silently — same lesson as the `unpackfs.conf` incident).

## Error handling

- Generator fails the build (non-zero exit, clear message) on: missing `config/installer.yaml` key, empty category, empty package group.
- Validator fails the build on: dangling `packagechooser@id` reference, empty `items:`.
- `gnegnolios-install` fails with clear stderr (existing pattern) if `zenity` or `calamares` binaries are missing.
- Driver auto-detect script: if `lspci` can't identify a known vendor, falls back to no extra driver packages (mesa generic already covers Intel/AMD via existing base packages) rather than failing the install.

## Testing

No test framework in this repo (shell-script build system). Verification is the existing pattern: `scripts/validate-calamares-config.sh` (new) is the automated check that runs on every build, same tier as `scripts/validate-installer-catalog.sh`. Manual verification: build the ISO, boot it, run all three modes (Express/Guided/Advanced) through to a completed install in a VM, confirm the resulting system has the expected packages/kernel/filesystem/bootloader for each mode.

## Out of scope (explicitly deferred)

- `post_install_hooks`, `service_selection` as distinct Advanced "unlocks" beyond what `optional_services`/`privacy` categories already cover as package choices.
- `package_source_selection` (choosing AUR helper behavior, Flatpak remotes) — categories already list `pacman`/`aur`/`flatpak` per option; no extra UI beyond what `packagechooser` shows.
- The original `installer.yaml` UI vision (single screen, expandable category cards) — explicitly rejected in favor of native multi-page Calamares wizard (see conversation: custom QML view module was the alternative, rejected as out of scope for this round).
