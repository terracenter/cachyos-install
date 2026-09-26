#!/bin/bash
step "Configurando Navegación, Rofi y Explorador de Archivos..."

# 1. Instalar dependencias base (Nautilus y Rofi)
info "Instalando Rofi y Nautilus (con sus extensiones)..."
sudo pacman -S --needed --noconfirm \
    rofi-wayland \
    nautilus \
    nautilus-python \
    gnome-disk-utility \
    dosfstools \
    exfatprogs \
    gvfs-mtp \
    gvfs-nfs \
    gvfs-smb \
    > /dev/null 2>&1 || warn "Algunas dependencias de navegación ya estaban instaladas o fallaron."
ok "Rofi y Nautilus instalados correctamente"

# 2. Descargar Dotfiles de Omarchy para Rofi
info "Clonando configuraciones de Rofi desde Omarchy..."
