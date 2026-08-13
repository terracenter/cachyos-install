#!/bin/bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ uninstall-hyprland-omarchy.sh                                               │
# │ Desinstalador limpio de Hyprland (Wayland) y paquetes asociados con paru    │
# └─────────────────────────────────────────────────────────────────────────────┘

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

step()  { echo -e "\n${BOLD}▶  $1${NC}"; }
ok()    { echo -e "   ${GREEN}✓  $1${NC}"; }
info()  { echo -e "   ${YELLOW}→  $1${NC}"; }
die()   { echo -e "\n   ${RED}✗  $1${NC}\n" >&2; exit 1; }

[[ $EUID -eq 0 ]] && die "No ejecutes el script como root. Ejecútalo con tu usuario normal."

# Paquetes exclusivos de Hyprland/Wayland
HYPRLAND_EXCLUSIVE_PKGS=(
    hyprland
    hypridle
    hyprlock
    hyprpicker
    hyprsunset
    hyprland-guiutils
    hyprland-preview-share-picker
    uwsm
    xdg-desktop-portal-hyprland
    waybar
    mako
    swayosd
    swaybg
    rofi-wayland
    gpu-screen-recorder
)

step "Desinstalando paquetes de Hyprland (Wayland) usando paru..."
PKGS_TO_REMOVE=()
for pkg in "${HYPRLAND_EXCLUSIVE_PKGS[@]}"; do
    if pacman -Q "$pkg" &>/dev/null; then
        PKGS_TO_REMOVE+=("$pkg")
    fi
done

if [ ${#PKGS_TO_REMOVE[@]} -gt 0 ]; then
    info "Removiendo paquetes: ${PKGS_TO_REMOVE[*]}"
    paru -Rns --noconfirm "${PKGS_TO_REMOVE[@]}" || true
    ok "Paquetes de Hyprland desinstalados"
else
    ok "No se encontraron paquetes de Hyprland pendientes de remover"
fi

step "Limpiando configuraciones de Hyprland..."
rm -rf "$HOME/.config/hypr" "$HOME/.config/waybar" "$HOME/.config/mako" "$HOME/.config/swayosd"
sudo rm -f /usr/share/wayland-sessions/hyprland.desktop

ok "Configuraciones de Hyprland desinstaladas con éxito."
