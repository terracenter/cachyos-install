#!/bin/bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ uninstall-qtile-omarchy.sh                                                  │
# │ Script de desinstalación de Qtile (X11) basado en install-qtile-omarchy.sh  │
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

# No ejecutar como root directo (usa paru / sudo internamente)
[[ $EUID -eq 0 ]] && die "No ejecutes el script directamente como root con sudo. Ejecútalo con tu usuario normal."

# Definición de paquetes exclusivos de Qtile / X11 instalados por install-qtile-omarchy.sh
# (Se excluyen utilidades compartidas con Hyprland/Wayland como alacritty, rofi, mako, bluetooth, etc.)
QTILE_EXCLUSIVE_PKGS=(
    qtile
    qtile-extras
    picom-ftlabs-git
    xorg-server
    xorg-xinit
    xorg-xset
    redshift
    xautolock
    i3lock-color
    feh
    shutter
    rofi-greenclip
)

step "Desinstalando paquetes exclusivos de Qtile (X11) usando paru..."
PKGS_TO_REMOVE=()
for pkg in "${QTILE_EXCLUSIVE_PKGS[@]}"; do
    if pacman -Q "$pkg" &>/dev/null; then
        PKGS_TO_REMOVE+=("$pkg")
    fi
done

if [ ${#PKGS_TO_REMOVE[@]} -gt 0 ]; then
    info "Removiendo paquetes: ${PKGS_TO_REMOVE[*]}"
    paru -Rns --noconfirm "${PKGS_TO_REMOVE[@]}" || true
    ok "Paquetes de Qtile desinstalados"
else
    ok "No se encontraron paquetes de Qtile pendientes de remover"
fi

step "Limpiando configuraciones de Qtile y sesiones de SDDM..."
# Eliminar configuraciones locales de Qtile / Picom
rm -rf "$HOME/.config/qtile" "$HOME/.config/picom"

# Eliminar entradas de sesiones para SDDM / Display Managers
sudo rm -f /usr/share/xsessions/qtile.desktop
sudo rm -f /usr/share/wayland-sessions/qtile-wayland.desktop
sudo rm -f /usr/share/wayland-sessions/qtile.desktop

# Eliminar scripts y accesos directos locales de Qtile
rm -f "$HOME/.local/bin/qtile-"*
rm -f "$HOME/.local/share/applications/qtile-"*.desktop

ok "Archivos de configuración y sesiones eliminados"

step "Verificando sesión de Hyprland (Wayland)..."
if pacman -Q hyprland &>/dev/null; then
    ok "Hyprland está listo para ser el entorno principal"
else
    info "Instalando Hyprland para asegurar el arranque en Wayland..."
    paru -S --needed --noconfirm hyprland waybar
fi

echo -e "\n${GREEN}${BOLD}✓ Desinstalación de Qtile completada exitosamente.${NC}"
echo -e "Puedes reiniciar con 'sudo reboot' o ejecutar 'Hyprland' para entrar a tu escritorio Wayland."
