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
tmp=$(mktemp -d)
if git clone --depth 1 https://github.com/basecamp/omarchy.git "$tmp" > /dev/null 2>&1; then
    # 3. Copiar configuración principal de Hyprland
    mkdir -p "$HOME/.config/hyprland"
    cp -r "$tmp/default/hyprland/." "$HOME/.config/hyprland/"
    
    # Asegurar que cualquier script de inicio tenga permisos de ejecución
    find "$HOME/.config/hyprland/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
    
    ok "Configuración de Hyprland y atajos (Omarchy) aplicados en ~/.config/hyprland"
else
    warn "No se pudo clonar el repositorio de Omarchy. Hyprland arrancará con la configuración genérica."
fi

# Limpieza
rm -rf "$tmp"
