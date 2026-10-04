#!/usr/bin/env bash
# Build the GnegnoliOS ISO.
#
#   ./build.sh            build the ISO into out/
#   ./build.sh --capture  first re-capture this machine (scripts/capture-system.sh)
#   ./build.sh --clean    remove work/ and out/
#
# Run as your normal user. sudo is used only to install missing build tools
# and AUR build dependencies (makepkg -s); mkarchiso itself runs unprivileged.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO="$ROOT/iso"
WORK="$ROOT/work"
OUT="$ROOT/out"
RELENG="${RELENG:-/usr/share/archiso/configs/releng}"

# Inside the VS Code Flatpak the host is only reachable through flatpak-spawn.
if [[ -f /.flatpak-info ]]; then
    exec flatpak-spawn --host "$0" "$@"
fi

say()  { printf '\e[1;31m::\e[0m \e[1m%s\e[0m\n' "$*"; }
die()  { printf '\e[1;31merror:\e[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -ne 0 ]] || die "Run as your normal user (makepkg refuses root)."

case "${1:-}" in
    --clean)   rm -rf "$WORK" "$OUT"; say "Cleaned."; exit 0 ;;
    --capture) "$ROOT/scripts/capture-system.sh" ;;
    "")        ;;
    *)         die "Unknown option: $1" ;;
esac

# ─── Build tools ──────────────────────────────────────────────────────────
need=()
for p in archiso git base-devel; do pacman -Qq "$p" &>/dev/null || need+=("$p"); done
if ((${#need[@]})); then
    say "Installing build tools: ${need[*]}"
    sudo pacman -S --needed --noconfirm "${need[@]}"
fi
[[ -d $RELENG ]] || die "$RELENG not found (is archiso installed?)"

# ─── AUR packages → local repo ────────────────────────────────────────────
REPO="$WORK/aur-repo"
mkdir -p "$REPO" "$WORK/aur-src"
rm -f "$REPO"/*

mapfile -t aur < <(grep -v '^[[:space:]]*#' "$ISO/aur.list" | grep .)
for pkg in "${aur[@]}"; do
    say "AUR: $pkg"
    src="$WORK/aur-src/$pkg"
    if [[ -d $src/.git ]]; then
        git -C "$src" pull -q --ff-only
    else
        git clone -q "https://aur.archlinux.org/$pkg.git" "$src"
    fi
    (
        cd "$src"
        # -s installs missing deps (sudo), -f rebuilds; skip if already built
        # at the current PKGBUILD version.
        if ! compgen -G "$pkg-*.pkg.tar.zst" >/dev/null ||
           [[ PKGBUILD -nt $(ls -t "$pkg"-*.pkg.tar.zst | head -n1) ]]; then
            makepkg -sf --noconfirm --needed
        fi
    )
    # Newest package of this name, not the -debug split.
    built="$(ls -t "$src"/*.pkg.tar.zst | grep -v -- '-debug-' | head -n1)"
    cp "$built" "$REPO/"
done
if ((${#aur[@]})); then
    repo-add -q "$REPO/gnegnolios-aur.db.tar.gz" "$REPO"/*.pkg.tar.zst
else
    # Empty repo still has to exist for pacman.conf.
    tar -czf "$REPO/gnegnolios-aur.db.tar.gz" -T /dev/null
    ln -sf gnegnolios-aur.db.tar.gz "$REPO/gnegnolios-aur.db"
fi

# ─── Assemble profile ─────────────────────────────────────────────────────
say "Assembling profile"
PROFILE="$WORK/profile"
rm -rf "$PROFILE"
mkdir -p "$PROFILE/airootfs"

# Boot loaders and boot-mode definitions come from the installed archiso, so
# they always match the installed mkarchiso.
cp -a "$RELENG"/{efiboot,grub,syslinux} "$PROFILE/"
[[ -f $RELENG/bootstrap_packages ]] && cp -a "$RELENG/bootstrap_packages" "$PROFILE/"
{ cat "$RELENG/profiledef.sh"; echo; cat "$ISO/profiledef.sh"; } > "$PROFILE/profiledef.sh"

# Branding of the boot menus.
grep -rlZ 'Arch Linux' "$PROFILE"/{efiboot,grub,syslinux} | xargs -0r sed -i \
    -e 's/Arch Linux install medium/GnegnoliOS live medium/g' \
    -e 's/Arch Linux/GnegnoliOS/g'

# Live-ISO plumbing from releng: initramfs hooks and pacman keyring on tmpfs.
for f in etc/mkinitcpio.conf.d/archiso.conf \
         etc/systemd/system/pacman-init.service \
         etc/systemd/system/etc-pacman.d-gnupg.mount \
         etc/pacman.d/hooks/zzzz99-remove-custom-hooks-from-airootfs.hook; do
    install -D -m 644 "$RELENG/airootfs/$f" "$PROFILE/airootfs/$f"
done
mkdir -p "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sf ../pacman-init.service \
    "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/pacman-init.service"

# GnegnoliOS root filesystem overlay (configs, skel, installer, wallpaper).
cp -a "$ISO/airootfs/." "$PROFILE/airootfs/"

# Package list: this machine's packages + live/installer extras + AUR.
cat "$ISO/packages.captured" "$ISO/packages.extra" "$ISO/aur.list" |
    sed 's/#.*//; s/[[:space:]]//g' | grep . | sort -u > "$PROFILE/packages.x86_64"

sed "s|@AUR_REPO@|$REPO|" "$ISO/pacman.conf" > "$PROFILE/pacman.conf"

# ─── Build ────────────────────────────────────────────────────────────────
say "Building ISO ($(wc -l < "$PROFILE/packages.x86_64") packages) — this takes a while"
rm -rf "$WORK/mkarchiso"
mkdir -p "$OUT"
mkarchiso -v -w "$WORK/mkarchiso" -o "$OUT" "$PROFILE"

iso="$(ls -t "$OUT"/*.iso | head -n1)"
say "Done: $iso ($(du -h "$iso" | cut -f1))"
echo "Write it to a USB stick with:"
echo "  sudo dd if=$iso of=/dev/sdX bs=4M status=progress oflag=sync"
