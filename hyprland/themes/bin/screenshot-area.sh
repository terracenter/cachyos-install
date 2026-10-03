#!/usr/bin/env bash
set -euo pipefail
PICTURES_DIR="$(xdg-user-dir PICTURES 2>/dev/null || printf '%s\n' "$HOME/Pictures")"
SS_DIR="$PICTURES_DIR/Capturas"
mkdir -p "$SS_DIR"
FILENAME="$SS_DIR/$(date +%Y%m%d_%H%M%S).png"
grim -g "$(slurp)" - | satty --filename - --output-filename "$FILENAME"
