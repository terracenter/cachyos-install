#!/usr/bin/env bash

set -Eeuo pipefail

THEMES_DIR="$HOME/.config/omarchy/themes"
CURRENT_DIR="$HOME/.config/omarchy/current"
APPLY="$HOME/.local/bin/theme-apply"

required_keys=(
    wallpaper
    accent
    foreground
    background
    selection_foreground
    selection_background
    color0
    color1
    color2
    color3
    color4
    color5
    color6
    color7
    color8
    color9
    color10
    color11
    color12
    color13
    color14
    color15
)

theme_is_valid() {
    local theme_dir="$1"
    local colors_file="$theme_dir/colors.toml"
    local key value

    [[ -f "$colors_file" ]] || return 1

    for key in "${required_keys[@]}"; do
        value=$(
            grep -m1 -E "^${key}[[:space:]]*=" "$colors_file" |
            sed 's/.*=[[:space:]]*"\(.*\)"/\1/'
        )

        [[ -n "$value" ]] || return 1
    done
}

mapfile -t themes < <(
    find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 |
    while IFS= read -r -d '' theme_dir; do
        if theme_is_valid "$theme_dir"; then
            basename "$theme_dir"
        fi
    done |
    sort
)

if ((${#themes[@]} == 0)); then
    notify-send "Temas" "No se encontraron temas válidos"
    exit 1
fi

current=$(cat "$CURRENT_DIR/theme" 2>/dev/null || printf 'ninguno')

theme=$(
    printf '%s\n' "${themes[@]}" |
    rofi -dmenu -i -p "Tema actual: $current"
) || exit 0

[[ -n "$theme" ]] || exit 0

rm -f "$CURRENT_DIR/wallpaper"

"$APPLY" "$theme"
