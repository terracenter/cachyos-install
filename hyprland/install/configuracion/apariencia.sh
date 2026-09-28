#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HYPRLAND_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
source "$HYPRLAND_DIR/install/basico/helpers.sh"

show_script_version "Apariencia Lua de Hyprland" "${BASH_SOURCE[0]}"
[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

step "Instalando temas y apariencia"
source_dir="$HYPRLAND_DIR/themes"
themes_dir="$HOME/.config/omarchy/themes"
current_dir="$HOME/.config/omarchy/current"
templates_dir="$HOME/.local/share/omarchy-local/themed"

mkdir -p "$themes_dir" "$current_dir" "$templates_dir" "$HOME/.local/bin"
find "$source_dir" -mindepth 1 -maxdepth 1 -type d \
    ! -name bin ! -name templates -exec cp -a {} "$themes_dir/" \;
cp -a "$source_dir/templates/." "$templates_dir/"
find "$themes_dir" -type f -name colors.toml -exec sed -i "s|/home/usuario|$HOME|g" {} +

install -Dm755 "$source_dir/bin/theme-apply.sh" "$HOME/.local/bin/theme-apply"
install -Dm755 "$source_dir/bin/theme-switcher.sh" "$HOME/.local/bin/theme-switcher"

"$HOME/.local/bin/theme-apply" nord
ok "Tema nord aplicado"
