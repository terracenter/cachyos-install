#!/usr/bin/env bash
set -euo pipefail

THEMES_DIR="${HOME}/.config/omarchy/themes"

TEMA=$(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort | rofi -dmenu -p "Tema" -i -theme-str 'window {width: 300px;}')
[[ -z "$TEMA" ]] && exit 0

"${HOME}/.local/bin/theme-apply" "$TEMA"
