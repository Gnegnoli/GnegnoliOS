#!/usr/bin/env bash
# Snapshot the running GnegnoliOS machine into the ISO profile.
#
# Captures: explicit repo packages, AUR packages, Flatpak apps, the user's
# desktop configuration (copied into /etc/skel of the ISO), the wallpaper and
# the SDDM / pacman configuration. Run it as your normal user whenever you
# change something on this machine and want the ISO to follow.
#
#   ./scripts/capture-system.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO="$ROOT/iso"
AIR="$ISO/airootfs"
SKEL="$AIR/etc/skel"
WALLDIR="/usr/share/backgrounds/gnegnolios"

# Inside the VS Code Flatpak the host is only reachable through flatpak-spawn.
if [[ -f /.flatpak-info ]]; then
    exec flatpak-spawn --host "$0" "$@"
fi

[[ $EUID -ne 0 ]] || { echo "Run as your normal user, not root." >&2; exit 1; }

say() { printf '\e[1;31m::\e[0m %s\n' "$*"; }

# ─── Packages ─────────────────────────────────────────────────────────────
say "Capturing package lists"
# Repo packages explicitly installed (no AUR, no -debug split packages).
pacman -Qqen | grep -v -- '-debug$' > "$ISO/packages.captured"
# AUR / foreign packages, without -debug splits.
pacman -Qqem | grep -v -- '-debug$' > "$ISO/aur.list"
# Flatpak apps (installed on first boot of the installed system).
if command -v flatpak >/dev/null; then
    flatpak list --app --columns=application | sort -u > "$AIR/etc/gnegnolios/flatpaks.list"
fi
echo "   repo: $(wc -l < "$ISO/packages.captured")  aur: $(wc -l < "$ISO/aur.list")  flatpak: $(wc -l < "$AIR/etc/gnegnolios/flatpaks.list")"

# ─── User configuration → /etc/skel ───────────────────────────────────────
say "Capturing desktop configuration into /etc/skel"
CONFIG_ITEMS=(
    kdeglobals kwinrc kwinrulesrc kglobalshortcutsrc kcminputrc ksplashrc
    plasmarc plasmashellrc plasma-org.kde.plasma.desktop-appletsrc
    plasmanotifyrc plasma-welcomerc powerdevilrc dolphinrc spectaclerc
    kdedefaults menus kmenueditrc
    gtk-3.0 gtk-4.0 gtkrc gtkrc-2.0 xsettingsd
    ghostty starship.toml krema kremarc appgridrc
    autostart environment.d gnegnolios
)
SHARE_ITEMS=(color-schemes applications)
HOME_ITEMS=(.zshrc .gtkrc-2.0)

rm -rf "$SKEL"
mkdir -p "$SKEL/.config" "$SKEL/.local/share"
for i in "${CONFIG_ITEMS[@]}"; do
    [[ -e "$HOME/.config/$i" ]] && cp -a "$HOME/.config/$i" "$SKEL/.config/"
done || true
for i in "${SHARE_ITEMS[@]}"; do
    [[ -e "$HOME/.local/share/$i" ]] && cp -a "$HOME/.local/share/$i" "$SKEL/.local/share/"
done || true
for i in "${HOME_ITEMS[@]}"; do
    [[ -e "$HOME/$i" ]] && cp -a "$HOME/$i" "$SKEL/"
done || true
# Personal GTK bookmarks point at this machine's folders.
rm -f "$SKEL/.config/gtk-3.0/bookmarks" "$SKEL/.config/gtk-4.0/bookmarks"

# ─── Wallpaper ────────────────────────────────────────────────────────────
say "Capturing wallpaper"
wall_uri="$(grep -m1 '^Image=' "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" | cut -d= -f2- || true)"
wall="${wall_uri#file://}"
mkdir -p "$AIR$WALLDIR"
rm -f "$AIR$WALLDIR"/*
if [[ -f "$wall" ]]; then
    cp -a "$wall" "$AIR$WALLDIR/"
    new="$WALLDIR/$(basename "$wall")"
    sed -i "s|^Image=.*|Image=file://$new|" "$SKEL/.config/plasma-org.kde.plasma.desktop-appletsrc"
    [[ -f "$SKEL/.config/gnegnolios/desktop.conf" ]] &&
        sed -i "s|^Wallpaper=.*|Wallpaper=$new|" "$SKEL/.config/gnegnolios/desktop.conf"
    echo "   $wall -> $new"
fi
sed -i '/^usersWallpapers=/d' "$SKEL/.config/plasmarc" 2>/dev/null || true

# Any leftover absolute path to this home becomes relative to the new user.
grep -rlI -- "$HOME" "$SKEL" 2>/dev/null | while read -r f; do
    echo "   warning: $f still references $HOME (left as-is)"
done || true

# ─── System configuration ─────────────────────────────────────────────────
say "Capturing system configuration"
mkdir -p "$AIR/etc/sddm.conf.d"
cp /etc/sddm.conf.d/default.conf /etc/sddm.conf.d/theme.conf "$AIR/etc/sddm.conf.d/"
cp /etc/pacman.conf "$AIR/etc/pacman.conf"

say "Done. Review with: git status iso/"
