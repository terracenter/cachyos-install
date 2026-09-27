#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

show_script_version "Hyprland Core" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal, no como root."
require_command sudo
require_command pacman

step "Instalando el nucleo minimo de Hyprland"

packages=(
    hyprland
    uwsm
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    qt5-wayland
    qt6-wayland
    polkit-gnome
    pipewire
    pipewire-audio
    pipewire-pulse
    wireplumber
    waybar
    rofi-wayland
    alacritty
    nautilus
    swaync
    hyprpaper
    hypridle
    hyprlock
    wl-clipboard
    cliphist
    network-manager-applet
    pavucontrol
    brightnessctl
    playerctl
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
    papirus-icon-theme
)

sudo pacman -S --needed --noconfirm "${packages[@]}"

ok "Nucleo minimo de Hyprland instalado"
