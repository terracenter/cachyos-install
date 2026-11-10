# CachyOS + Omarchy Installer

![License](https://img.shields.io/badge/license-GPL--3.0-blue)
![Status](https://img.shields.io/badge/status-Active-brightgreen)
![Stack](https://img.shields.io/badge/stack-Bash_%7C_Hyprland_%7C_Qtile-informational)

Modular CachyOS installer based on Omarchy with additional customizations, integrated documentation and support for Hyprland and Qtile.

## Features

- CachyOS + BTRFS + Snapper.
- Modular Hyprland setup.
- Persistent monitor management with nwg-displays.
- Customized Waybar.
- Per-application audio controls.
- Integrated screenshot tools.
- Qtile support.
- Technical handbook.

## Screenshot Shortcuts

- Print: Area screenshot.
- Super + Print: Full screenshot.
- Super + Shift + Print: Active window.
- Ctrl + Print: Copy screenshot to clipboard.

## Installation

```bash
git clone https://github.com/terracenter/cachyos-install.git
cd cachyos-install
./install.sh
```

## Installation flow

![Installation flow (labels in Spanish, as in the installer menu)](docs/flujo-instalacion.svg)

## License

GPL-3.0 (see `LICENSE`). Based on Omarchy (MIT); its notice is in `THIRD-PARTY-LICENSES.md`.
