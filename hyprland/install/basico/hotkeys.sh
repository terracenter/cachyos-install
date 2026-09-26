#!/bin/bash
step "Instalando Entorno Core de Hyprland y configuración Omarchy..."

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
    uwsm \
    > /dev/null 2>&1 || warn "Algunas dependencias core ya estaban instaladas o fallaron."
ok "Dependencias de Hyprland instaladas"

# 2. Clonar y copiar dotfiles reales de Omarchy (default/hypr/ es la ruta correcta)
info "Aplicando configuración Hyprland desde Omarchy..."
tmp=$(mktemp -d)
if git clone --depth 1 https://github.com/basecamp/omarchy.git "$tmp" > /dev/null 2>&1; then
    # Configuración core de Hyprland
    mkdir -p "$HOME/.config/hypr"
    cp -r "$tmp/default/hypr/." "$HOME/.config/hypr/"
    find "$HOME/.config/hypr" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    ok "Configuración de Hyprland (Omarchy) aplicada en ~/.config/hypr"

    # Alacritty (terminal por defecto de Omarchy)
    if [[ -d "$tmp/default/alacritty" ]]; then
        mkdir -p "$HOME/.config/alacritty"
        cp -r "$tmp/default/alacritty/." "$HOME/.config/alacritty/"
        ok "Configuración de Alacritty (Omarchy) aplicada"
    fi

    # Waybar (barra superior)
    if [[ -d "$tmp/default/waybar" ]]; then
        mkdir -p "$HOME/.config/waybar"
        cp -r "$tmp/default/waybar/." "$HOME/.config/waybar/"
        find "$HOME/.config/waybar" -type f -exec chmod +x {} \; 2>/dev/null || true
        ok "Configuración de Waybar (Omarchy) aplicada"
    fi
else
    warn "No se pudo clonar Omarchy. Hyprland arrancará sin configuración — configura ~/.config/hypr/ manualmente."
fi
rm -rf "$tmp"
