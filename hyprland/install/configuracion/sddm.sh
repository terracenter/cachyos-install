#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=../basico/helpers.sh
source "$SCRIPT_DIR/../basico/helpers.sh"

show_script_version "SDDM para Hyprland" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

step "Instalando y habilitando SDDM"

sudo pacman -S --needed --noconfirm sddm xorg-server

sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-hyprland.conf >/dev/null <<'SDDMCONF'
[General]
DisplayServer=x11

[Theme]
CursorTheme=Adwaita
SDDMCONF

sudo systemctl enable sddm.service

if [[ ! -f /usr/share/wayland-sessions/hyprland.desktop ]] && \
   [[ ! -f /usr/share/wayland-sessions/hyprland-uwsm.desktop ]]; then
    die "No se encontro una sesion Hyprland en /usr/share/wayland-sessions/."
fi

ok "SDDM habilitado para el proximo arranque"
