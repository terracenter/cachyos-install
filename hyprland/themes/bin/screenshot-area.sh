#!/usr/bin/env bash
set -euo pipefail
SS_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SS_DIR"
FILENAME="$SS_DIR/$(date +%Y%m%d_%H%M%S).png"
grim -g "$(slurp)" - | satty --filename - --output-filename "$FILENAME"
