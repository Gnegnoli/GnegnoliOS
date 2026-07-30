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
