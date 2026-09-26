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
    # Configuración core de Hyprland (Generada nativa para evitar el fallo de Lua de Omarchy)
    mkdir -p "$HOME/.config/hypr"
    cat > "$HOME/.config/hypr/hyprland.conf" << 'HYPREOF'
# Configuración base de Hyprland estilo Omarchy

# Autostart
exec-once = waybar
exec-once = swaync
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = hyprpaper
exec-once = hypridle

# Monitores
monitor=,preferred,auto,auto

# Variables de entorno
env = XCURSOR_SIZE,24

# Input
input {
    kb_layout = us,es
    kb_options = grp:win_space_toggle
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

# General y Decoración
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}
decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = yes
    shadow_range = 4
}

# Atajos Principales
$mainMod = SUPER
bind = $mainMod, Return, exec, alacritty
bind = $mainMod, Q, killactive, 
bind = $mainMod, M, exit, 
bind = $mainMod, E, exec, nautilus
bind = $mainMod, V, togglefloating, 
bind = $mainMod, Space, exec, rofi -show drun
bind = $mainMod SHIFT, B, exec, ~/.local/bin/sddm-bg-switcher
bind = $mainMod, F, fullscreen,

# Foco y Workspaces
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4

# Multimedia
bind = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bind = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bind = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
HYPREOF
    ok "Configuración de Hyprland (Nativa Vainilla) aplicada en ~/.config/hypr"

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
