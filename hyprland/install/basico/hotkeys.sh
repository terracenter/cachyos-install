#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

show_script_version "Configuracion base de Hyprland" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal, no como root."

step "Creando configuracion base y atajos de Hyprland"

config_dir="$HOME/.config/hypr"
config_file="$config_dir/hyprland.conf"
backup_file="${config_file}.bak.$(date +%Y%m%d_%H%M%S)"

mkdir -p "$config_dir"

if [[ -f "$config_file" ]]; then
    cp -a "$config_file" "$backup_file"
    info "Respaldo creado: $backup_file"
fi

cat > "$config_file" <<'HYPRCONF'
# CachyOS Hyprland base

monitor = , preferred, auto, 1

$mainMod = SUPER
$terminal = alacritty
$fileManager = nautilus
$menu = rofi -show drun

exec-once = uwsm app -- waybar
exec-once = uwsm app -- swaync
exec-once = uwsm app -- nm-applet --indicator
exec-once = uwsm app -- hypridle
exec-once = uwsm app -- hyprpaper
exec-once = uwsm app -- /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
exec-once = wl-paste --type text --watch cliphist store
exec-once = wl-paste --type image --watch cliphist store
exec-once = dbus-update-activation-environment --systemd --all

input {
    kb_layout = us,latam
    kb_options = grp:win_space_toggle
    follow_mouse = 1

    touchpad {
        natural_scroll = true
        tap-to-click = true
    }
}

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    layout = dwindle
    col.active_border = rgba(89b4faff)
    col.inactive_border = rgba(585b70aa)
}

decoration {
    rounding = 10

    blur {
        enabled = true
        size = 3
        passes = 1
    }
}

animations {
    enabled = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
}

bind = $mainMod, Q, exec, $terminal
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, SPACE, exec, $menu
bind = $mainMod SHIFT, W, killactive
bind = $mainMod, F, fullscreen
bind = $mainMod, T, togglefloating
bind = $mainMod, M, exit
bind = $mainMod CTRL, L, exec, hyprlock

bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

bindel = , XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
bindel = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindel = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
HYPRCONF

ok "Configuracion creada en $config_file"
