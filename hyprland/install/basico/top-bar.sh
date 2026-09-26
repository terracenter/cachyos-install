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
