#!/bin/bash
step "Configurando Barra Superior (Waybar)..."

# 1. Instalar dependencias visuales de Omarchy (Nerd Fonts y Temas)
info "Instalando fuentes e iconos de Omarchy..."
sudo pacman -S --needed --noconfirm \
    ttf-jetbrains-mono-nerd \
    papirus-icon-theme \
    catppuccin-gtk-theme-mocha \
    catppuccin-cursors-mocha \
    waybar \
    rofi-wayland \
    > /dev/null 2>&1 || warn "Algunas dependencias visuales ya estaban o fallaron, continuando..."
ok "Fuentes e iconos instalados"

# 2. Descargar Dotfiles de Omarchy
info "Clonando configuraciones de Omarchy (GitHub)..."
tmp=$(mktemp -d)
if git clone --depth 1 https://github.com/basecamp/omarchy.git "$tmp" > /dev/null 2>&1; then
    # 3. Copiar configuración de Waybar
    mkdir -p "$HOME/.config/waybar"
    cp -r "$tmp/default/waybar/." "$HOME/.config/waybar/"
    
    # Dar permisos de ejecución a los scripts de waybar
    find "$HOME/.config/waybar/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
    
    ok "Configuración de Waybar (Omarchy) aplicada en ~/.config/waybar"
else
    die "No se pudo clonar el repositorio de Omarchy. Revisa tu conexión a internet."
fi

# Limpieza
rm -rf "$tmp"
