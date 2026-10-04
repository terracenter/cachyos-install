#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

# shellcheck source=../basico/helpers.sh
source "$SCRIPT_DIR/../basico/helpers.sh"

show_script_version "GRUB Astronaut" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

[[ -f /etc/default/grub ]] || {
    info "GRUB no detectado. Omitiendo configuración."
    exit 0
}

step "Configurando tema Astronaut para GRUB"

themes_dir="/usr/share/grub/themes"
theme_dir="${themes_dir}/astronaut"

mkdir -p "$themes_dir"

# Si el tema aún no existe, crearlo a partir de Catppuccin
if [[ ! -d "$theme_dir" ]]; then
    source_dir="${themes_dir}/catppuccin-mocha-grub-theme"

    [[ -d "$source_dir" ]] || \
        die "No existe catppuccin-mocha-grub-theme"

    sudo cp -r "$source_dir" "$theme_dir"

    if [[ -f /usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/astronaut.png ]]; then
        sudo cp \
            /usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/astronaut.png \
            "$theme_dir/background.png"
    fi

    if [[ -f "$theme_dir/theme.txt" ]]; then
        sudo sed -i '/# Logo image/,/^}/d' "$theme_dir/theme.txt"
    fi

    ok "Tema Astronaut creado"
else
    ok "Tema Astronaut ya existe"
fi

theme_file="${theme_dir}/theme.txt"

[[ -f "$theme_file" ]] || die "No se encontró theme.txt"

sudo sed -i '/^GRUB_THEME=/d' /etc/default/grub

echo "GRUB_THEME=\"$theme_file\"" | sudo tee -a /etc/default/grub >/dev/null

ok "GRUB_THEME configurado"

step "Regenerando grub.cfg"

sudo grub-mkconfig -o /boot/grub/grub.cfg \
    || die "No se pudo regenerar grub.cfg"

ok "GRUB Astronaut configurado correctamente"
