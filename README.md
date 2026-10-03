# Instalador de CachyOS + Omarchy + Personalizaciones

Instalador modular para CachyOS basado en Omarchy, con personalizaciones propias, documentación integrada y soporte para Hyprland y Qtile.

## Características

- CachyOS + BTRFS + Snapper.
- Hyprland modular basado en Omarchy.
- Gestión visual y persistente de monitores mediante nwg-displays.
- Waybar personalizada.
- Audio por aplicación desde Waybar.
- Capturas de pantalla integradas.
- Qtile como entorno alternativo.
- Documentación técnica por capítulos.

## Capturas de pantalla

- Print: Captura de área.
- Super + Print: Captura completa.
- Super + Shift + Print: Captura de ventana.
- Ctrl + Print: Captura al portapapeles.

## Instalación rápida

### Live USB

```bash
pacman -Sy --noconfirm git
git clone https://github.com/terracenter/cachyos-install.git /tmp/cachyos-install
cd /tmp/cachyos-install
sudo ./install.sh
```

### Sistema instalado

```bash
git clone https://github.com/terracenter/cachyos-install.git ~/cachyos-install
cd ~/cachyos-install
./install.sh
```

## Estructura

```text
base/
hyprland/
qtile/
docs/
```

## Documentación

La documentación completa se encuentra en la carpeta docs/.
