#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

show_script_version "Navegacion del escritorio" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal, no como root."

step "Configurando Rofi y Nautilus"

mkdir -p "$HOME/.config/rofi"

cat > "$HOME/.config/rofi/config.rasi" <<'ROFI'
configuration {
    modi: "drun,run,window";
    show-icons: true;
    icon-theme: "Papirus-Dark";
    drun-display-format: "{name}";
    font: "JetBrainsMono Nerd Font 12";
}
ROFI

xdg-mime default org.gnome.Nautilus.desktop inode/directory application/x-gnome-saved-search || true

ok "Rofi y Nautilus configurados"
