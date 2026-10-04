# GnegnoliOS

A bootable, installable ISO that replicates this machine: Arch Linux +
KDE Plasma 6 (Wayland) with the NERV theme, Krema dock, AppGrid, the ltmnight
SDDM theme, Ghostty + zsh + starship, and the same packages and Flatpak apps.

The previous multi-desktop project lives in [OLD/](OLD/).

## How it works

```
this machine ──capture-system.sh──▶ iso/ ──build.sh──▶ out/gnegnolios-*.iso
                                                          │
                       boot on another PC: live Plasma ◀──┘
                       "Install GnegnoliOS" ──▶ identical installed system
```

| Path | What |
|---|---|
| [scripts/capture-system.sh](scripts/capture-system.sh) | Snapshots this machine into `iso/`: package lists, AUR list, Flatpak list, desktop config (into `/etc/skel`), wallpaper, SDDM and pacman config |
| [iso/packages.captured](iso/packages.captured) | Repo packages explicitly installed here (generated) |
| [iso/aur.list](iso/aur.list) | AUR packages, built by `build.sh` into a local repo (generated) |
| [iso/packages.extra](iso/packages.extra) | Hand-written extras: live boot, installer tools, Intel GPU/CPU support |
| [iso/airootfs/](iso/airootfs/) | Files laid over the system root. `etc/skel` is the captured desktop config every new user gets |
| [iso/airootfs/usr/local/bin/gnegnolios-install](iso/airootfs/usr/local/bin/gnegnolios-install) | The installer |
| [build.sh](build.sh) | Builds AUR packages, assembles the archiso profile on top of the installed `releng` profile, runs `mkarchiso` |

## Build

```sh
./build.sh              # build out/gnegnolios-YYYY.MM.DD-x86_64.iso
./build.sh --capture    # re-capture this machine first, then build
./build.sh --clean      # remove work/ and out/
```

Run as your normal user. `sudo` is asked only to install missing build tools
(`archiso`, `base-devel`, `git`) and AUR build dependencies. `mkarchiso` runs
unprivileged through user namespaces; if that fails on your setup, run
`sudo mkarchiso -v -w work/mkarchiso -o out work/profile` after a first
`./build.sh` has assembled `work/profile`.

Write the ISO to a USB stick:

```sh
sudo dd if=out/gnegnolios-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

## Install on another PC

1. Boot the USB stick (UEFI or legacy BIOS). It logs into a live Plasma
   session as user `live` (password `live`).
2. Double-click **Install GnegnoliOS** on the desktop (or run
   `sudo gnegnolios-install` from any terminal / TTY).
3. Choose:
   - **Erase an entire disk**: GPT, 1 GiB EFI partition + ext4 root
     (BIOS: 1 MiB BIOS-boot partition + ext4 root).
   - **Use existing partitions** (dual boot): pick a root partition to format
     and, on UEFI, an existing EFI partition that is reused without
     formatting. GRUB detects other systems via os-prober.
4. Answer hostname, user, password, time zone, keyboard, language, autologin,
   Flatpak apps. Nothing is written before the final confirmation.

The installer copies the ISO's system image to disk, so it works offline and
the result is identical to the live session. The Flatpak apps are installed
in the background on the first boot with internet
(`gnegnolios-flatpaks.service`, retried every boot until it succeeds).

## Keeping the ISO in sync

After changing something on this machine (new package, new theme tweak):

```sh
./build.sh --capture
git diff iso/            # review what changed
```

Only the config files listed in `CONFIG_ITEMS` in
[capture-system.sh](scripts/capture-system.sh) go into the ISO; add new ones
there. Personal data (browser profiles, shell history, SSH keys, documents)
is never captured.

## Not replicated

- NVIDIA proprietary drivers (nouveau is used; add `nvidia-open` to
  `packages.extra` if needed).
- Monitor layout (`kwinoutputconfig.json`) and per-machine state.
- Swap: none, same as this machine.
