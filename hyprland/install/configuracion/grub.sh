#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=../basico/helpers.sh
source "$SCRIPT_DIR/../basico/helpers.sh"

show_script_version "GRUB Catppuccin" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

[[ -f /etc/default/grub ]] || {
    info "GRUB no detectado. Omitiendo configuracion."
    exit 0
}

step "Instalando tema Catppuccin para GRUB"

themes_dir="/usr/share/grub/themes"
theme_dir="${themes_dir}/catppuccin-mocha-grub-theme"
tmp_dir="$(mktemp -d)"

mkdir -p "$themes_dir"

if [[ ! -d "$theme_dir" ]]; then
    git clone --depth 1 https://github.com/catppuccin/grub.git "$tmp_dir/catppuccin" \
        || die "No se pudo descargar catppuccin/grub"

    sudo cp -r \
        "$tmp_dir/catppuccin/src/catppuccin-mocha-grub-theme" \
        "$themes_dir/" \
        || die "No se pudo instalar el tema Catppuccin"

    ok "Tema Catppuccin Mocha instalado"
else
    ok "Tema Catppuccin Mocha ya instalado"
fi

rm -rf "$tmp_dir"

theme_file="${theme_dir}/theme.txt"

[[ -f "$theme_file" ]] || die "No se encontro theme.txt"

sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub

echo "GRUB_THEME=\"$theme_file\"" | sudo tee -a /etc/default/grub >/dev/null

ok "GRUB_THEME configurado"

step "Regenerando grub.cfg"

sudo grub-mkconfig -o /boot/grub/grub.cfg \
    || die "No se pudo regenerar grub.cfg"

ok "GRUB Catppuccin configurado correctamente"
