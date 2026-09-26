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
tmp=$(mktemp -d)
if git clone --depth 1 https://github.com/basecamp/omarchy.git "$tmp" > /dev/null 2>&1; then
    # 3. Copiar configuración y scripts de Rofi
    mkdir -p "$HOME/.config/rofi"
    cp -r "$tmp/default/rofi/." "$HOME/.config/rofi/"
    
    # Asegurar que los scripts interactivos dentro de Rofi sean ejecutables
    find "$HOME/.config/rofi/scripts" -type f -exec chmod +x {} \; 2>/dev/null || true
    
    ok "Configuración visual y scripts de Rofi (Omarchy) aplicados en ~/.config/rofi"
else
    warn "No se pudo clonar el repositorio de Omarchy. Los menús de Rofi quedarán con el estilo por defecto."
fi

# Limpieza
rm -rf "$tmp"
