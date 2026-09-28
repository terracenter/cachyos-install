#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/../basico/helpers.sh"
show_script_version "Entrada Lua de Hyprland" "${BASH_SOURCE[0]}"
[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

step "Configurando teclado, mouse y touchpad"
mkdir -p "$HOME/.config/hypr/modules"

layout=$(whiptail --title "Distribucion del teclado" --menu "Selecciona tu teclado:" 15 65 4 \
    "latam" "Latinoamericano" \
    "us" "Ingles de Estados Unidos" \
    "us-intl" "Ingles internacional con acentos" \
    "es" "Espanol" 3>&1 1>&2 2>&3) || layout="latam"

case "$layout" in
    us-intl) kb_layout="us"; kb_variant="intl" ;;
    *) kb_layout="$layout"; kb_variant="" ;;
esac

sensitivity=$(whiptail --title "Velocidad del puntero" --inputbox \
    "Valor entre -1.0 y 1.0. 0 conserva la velocidad normal:" 10 65 "0" 3>&1 1>&2 2>&3) || sensitivity="0"
[[ $sensitivity =~ ^-?(0(\.[0-9]+)?|1(\.0+)?)$ ]] || sensitivity="0"

natural=false; tap=true; disable_typing=true; clickfinger=true
if grep -qiE 'touchpad|trackpad' /proc/bus/input/devices 2>/dev/null; then
    whiptail --title "Touchpad" --yesno "Activar desplazamiento natural?" 8 60 && natural=true
    whiptail --title "Touchpad" --defaultno --yesno "Desactivar tocar para hacer clic?" 8 60 && tap=false
    whiptail --title "Touchpad" --defaultno --yesno "Mantener activo el touchpad mientras escribes?" 8 70 && disable_typing=false
fi

cat > "$HOME/.config/hypr/modules/input.lua" <<LUA
hl.config({
    input = {
        kb_layout = "$kb_layout",
        kb_variant = "$kb_variant",
        follow_mouse = 1,
        sensitivity = $sensitivity,
        touchpad = {
            natural_scroll = $natural,
            tap_to_click = $tap,
            disable_while_typing = $disable_typing,
            clickfinger_behavior = $clickfinger,
        },
    },
})
LUA
ok "Configuracion de entrada Lua creada"
