<div align="center">

<img src="packages/gnegnolios-branding/rootfs/usr/share/gnegnolios/logos/gnegnolios-mark.png" width="140" alt="GnegnoliOS mark" />

# GnegnoliOS

### Power. Elegance. Darkness. Precision.

**A premium Arch Linux distribution, built for professionals — not another generic Arch derivative.**

[![Base](https://img.shields.io/badge/base-Arch%20Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white)](https://archlinux.org)
[![Desktop](https://img.shields.io/badge/desktop-KDE%20Plasma-1D99F3?style=for-the-badge&logo=kde&logoColor=white)](https://kde.org)
[![Filesystem](https://img.shields.io/badge/filesystem-btrfs%20%2B%20snapper-7A0F16?style=for-the-badge)](#)
[![Status](https://img.shields.io/badge/status-alpha%200.1-0D0D0D?style=for-the-badge)](#)
[![License](https://img.shields.io/badge/license-custom-323232?style=for-the-badge)](#)

</div>

<br/>

<div align="center">
<img src="packages/gnegnolios-branding/rootfs/usr/share/wallpapers/GnegnoliOSGenesis/contents/images/1536x1024.png" width="100%" alt="GnegnoliOS Genesis wallpaper" />
<sub>Default wallpaper — <b>Genesis</b></sub>
</div>

<br/>

## Cos'è

**GnegnoliOS** è una distribuzione Linux basata su **Arch Linux** pensata per sentirsi come un prodotto costruito da una grande azienda: solida, affidabile, restrained, visivamente inconfondibile — dal primo boot.

Non è un remaster con un wallpaper diverso. È un sistema con **identità propria, default curati, e un'esperienza prodotto deliberata**, dal boot splash all'installer, dal tema del terminale all'ISO stessa.

> "Il logo porta il brand. GnegnoliOS non ha bisogno di una mascotte."

## Obiettivi

- **Zero frizione dal primo boot.** Driver, firmware, codec, snapshot, power management: funzionano out of the box.
- **Un solo installer intelligente.** Non un elenco infinito di checkbox: profili curati (Express / Guided / Advanced) che coprono developer, gamer, creator, sysadmin, enterprise.
- **Single source of truth.** Ogni componente deriva la sua configurazione da [`config/distro.yaml`](config/distro.yaml) — niente duplicazione, automazione ovunque possibile.
- **Un'identità visiva coerente su ogni superficie**: logo, GRUB, Plymouth, SDDM, Plasma, cursori, terminale, Firefox, Calamares, sito, documentazione.
- **Costruito per chi lavora davvero sulla macchina**: developer, sysadmin, musicisti, creator, streamer, video editor, power user, aziende.

## Chi lo usa

| | | | |
|---|---|---|---|
| 👨‍💻 Developer | 🛠️ Power user | 🖥️ SysAdmin | 🎚️ Musicisti |
| 🎬 Content creator | 📡 Streamer | ✂️ Video editor | 🏢 Enterprise |

## Stack tecnico

| Componente | Scelta |
|---|---|
| Base | Arch Linux |
| Package manager | `pacman` + `yay` (AUR) |
| Kernel | `linux`, `linux-lts` |
| Desktop | KDE Plasma (Wayland) |
| Display manager | SDDM |
| Filesystem | Btrfs + Snapper |
| Bootloader | GRUB |
| Init | systemd |
| Audio | PipeWire |
| Firewall | ufw |
| Installer | Calamares + Smart Installer Catalog |
| Sandboxing | Flatpak |

## Identità visiva

<div align="center">
<img src="packages/gnegnolios-branding/rootfs/usr/share/gnegnolios/sddm/login.png" width="49%" alt="SDDM login theme" />
<img src="packages/gnegnolios-branding/rootfs/usr/share/gnegnolios/plymouth/logo.png" width="49%" alt="Plymouth boot logo" />
<br/>
<sub>Login screen (SDDM) — Boot splash (Plymouth)</sub>
</div>

Il linguaggio visivo combina minimalismo corporate, geometria gotico-architettonica, acciaio forgiato, pietra vulcanica, marmo nero — atmosfera dark fantasy *restrained*, mai horror, mai neon, mai cyberpunk.

**Palette**

| Token | | Hex | Uso |
|---|---|---|---|
| Matte Black | ![#0D0D0D](https://placehold.co/16x16/0D0D0D/0D0D0D.png) | `#0D0D0D` | Background primario |
| Charcoal | ![#1B1B1B](https://placehold.co/16x16/1B1B1B/1B1B1B.png) | `#1B1B1B` | Superfici rialzate |
| Steel | ![#323232](https://placehold.co/16x16/323232/323232.png) | `#323232` | Divisori |
| Graphite | ![#4D4D4D](https://placehold.co/16x16/4D4D4D/4D4D4D.png) | `#4D4D4D` | Controlli muti |
| Dark Crimson | ![#7A0F16](https://placehold.co/16x16/7A0F16/7A0F16.png) | `#7A0F16` | Accento, focus, progress |
| Metal Silver | ![#A8A8A8](https://placehold.co/16x16/A8A8A8/A8A8A8.png) | `#A8A8A8` | Testo secondario |
| White | ![#EDEDED](https://placehold.co/16x16/EDEDED/EDEDED.png) | `#EDEDED` | Testo primario |

Dettagli completi in [`docs/BRAND_SYSTEM.md`](docs/BRAND_SYSTEM.md).

## Struttura del repo

```
GnegnoliOS/
├── config/          # distro.yaml — single source of truth, installer.yaml — catalogo Smart Installer
├── distro/          # profilo archiso, tutto ciò che serve per generare la ISO
├── packages/        # pacchetti custom (branding, calamares-config, installer-config, release...)
├── profiles/        # pacchetti per desktop / kernel / feature, combinati a build-time
├── calamares/        # configurazione installer
├── scripts/         # motore di build (scripts/lib/*.sh)
└── docs/            # architettura, brand system, product brief, smart installer
```

Architettura completa in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Smart Installer

Calamares guidato da un catalogo dichiarativo ([`config/installer.yaml`](config/installer.yaml)) con tre modalità:

- **Express** — sistema pronto all'uso, zero domande.
- **Guided** *(consigliata)* — profili smart per categoria (browser, dev, gaming, virtualizzazione, driver...).
- **Advanced** — controllo granulare su filesystem, kernel, bootloader, servizi, pacchetti.

Dettagli in [`docs/SMART_INSTALLER.md`](docs/SMART_INSTALLER.md).

## Build

```bash
./scripts/build.sh
```

La build:
1. carica `config/distro.yaml` e valida la configurazione;
2. compone la lista pacchetti da `profiles/base.yaml` + desktop + kernel + feature profile selezionati;
3. compila i pacchetti custom di `packages/` e li pubblica in un repo pacman locale;
4. genera l'ISO via `mkarchiso`.

Output in `build/output/gnegnolios-*.iso`.

## Stato del progetto

`v0.1-alpha` — in sviluppo attivo. Struttura, branding e build engine consolidati; installer e profili in espansione continua.

<div align="center">
<br/>
<sub>GnegnoliOS — costruito per essere usato sul serio.</sub>
</div>
