#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

show_script_version "Waybar base" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal, no como root."

step "Configurando Waybar"

waybar_dir="$HOME/.config/waybar"
mkdir -p "$waybar_dir"

cat > "$waybar_dir/config.jsonc" <<'JSON'
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "spacing": 8,
    "modules-left": ["custom/launcher", "hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["network", "pulseaudio", "cpu", "memory", "battery", "tray"],

    "custom/launcher": {
        "format": "󰣇",
        "on-click": "rofi -show drun",
        "tooltip": false
    },

    "hyprland/workspaces": {
        "format": "{name}",
        "on-click": "activate"
    },

    "clock": {
        "format": "{:%A %H:%M}",
        "format-alt": "{:%d/%m/%Y}"
    },

    "network": {
        "format-wifi": "󰖩  {essid}",
        "format-ethernet": "󰈀  {ipaddr}",
        "format-disconnected": "󰖪"
    },

    "pulseaudio": {
        "format": "󰕾  {volume}%",
        "format-muted": "󰖁",
        "on-click": "pavucontrol"
    },

    "cpu": {
        "format": "󰻠  {usage}%"
    },

    "memory": {
        "format": "󰍛  {percentage}%"
    },

    "battery": {
        "format": "󰁹  {capacity}%",
        "format-charging": "󰂄  {capacity}%"
    },

    "tray": {
        "spacing": 8
    }
}
JSON

cat > "$waybar_dir/style.css" <<'CSS'
@import "../omarchy/current/waybar-colors.css";
* {
    font-family: "JetBrainsMono Nerd Font";
    font-size: 12px;
    min-height: 0;
}

window#waybar {
    background: rgba(30, 30, 46, 0.94);
    color: #cdd6f4;
    border-bottom: 2px solid #89b4fa;
}

#custom-launcher,
#workspaces,
#clock,
#network,
#pulseaudio,
#cpu,
#memory,
#battery,
#tray {
    padding: 0 10px;
    margin: 4px 2px;
    border-radius: 8px;
    background: #313244;
}

#workspaces button {
    padding: 0 7px;
    color: #a6adc8;
}

#workspaces button.active {
    color: #1e1e2e;
    background: #89b4fa;
}
CSS

ok "Waybar configurado"
