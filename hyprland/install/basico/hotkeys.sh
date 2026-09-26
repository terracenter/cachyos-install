#!/bin/bash
step "Configurando Entorno Core de Hyprland y Atajos..."

# 1. Instalar dependencias core del entorno
info "Instalando paquetes base del entorno gráfico y portales..."
sudo pacman -S --needed --noconfirm \
    hyprland \
    xdg-desktop-portal-hyprland \
    qt5-wayland \
    qt6-wayland \
    polkit-kde-agent \
    cliphist \
    wl-clipboard \
    swaync \
    hyprpaper \
    hyprpicker \
    hypridle \
    hyprlock \
    > /dev/null 2>&1 || warn "Algunas dependencias core ya estaban instaladas o fallaron."
ok "Dependencias de Hyprland instaladas"

# 2. Descargar Dotfiles de Omarchy para Hyprland
info "Clonando configuraciones core de Omarchy..."
