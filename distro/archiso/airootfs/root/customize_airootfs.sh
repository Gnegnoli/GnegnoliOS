#!/usr/bin/env bash
set -e

useradd -m -G wheel -s /usr/bin/bash live
echo "root:live" | chpasswd
echo "live:live" | chpasswd

systemctl enable NetworkManager
systemctl enable sddm
systemctl enable cups
systemctl enable docker
systemctl enable bluetooth
systemctl enable vboxservice

systemctl set-default graphical.target

# Theme is set statically via the gnegnolios-branding package's
# /etc/plymouth/plymouthd.conf. -R here would rebuild via mkinitcpio's
# "linux" preset, which doesn't match archiso's own initramfs (built
# later by mkarchiso itself) and fails in this chroot anyway.
plymouth-set-default-theme gnegnolios || true
