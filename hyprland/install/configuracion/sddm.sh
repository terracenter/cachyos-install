#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/../basico/helpers.sh"

show_script_version "SDDM para Hyprland" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

step "Instalando y habilitando SDDM"

paru -S --needed --noconfirm \
    sddm \
    xorg-server \
    sddm-astronaut-theme \
    woff2-font-awesome

if ! pacman -Qq sddm-astronaut-theme >/dev/null 2>&1; then
    die "sddm-astronaut-theme no se pudo instalar"
fi

sudo mkdir -p /etc/sddm.conf.d

sudo tee /etc/sddm.conf.d/10-hyprland.conf >/dev/null <<'SDDMCONF'
[General]
DisplayServer=x11

[Theme]
Current=sddm-astronaut-theme
CursorTheme=Adwaita
SDDMCONF

if [[ ! -f /etc/sddm.conf.d/sddm-astronaut-theme.conf ]] \
   && [[ -f /usr/share/sddm/themes/sddm-astronaut-theme/theme.conf ]]; then
    sudo cp \
        /usr/share/sddm/themes/sddm-astronaut-theme/theme.conf \
        /etc/sddm.conf.d/sddm-astronaut-theme.conf
fi

sudo systemctl enable sddm.service

if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]] && \
   [[ ! -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]]; then
    die "No se encontro una sesion Hyprland en /usr/share/wayland-sessions/."
fi

ok "SDDM Astronaut configurado"
ok "SDDM habilitado para el proximo arranque"