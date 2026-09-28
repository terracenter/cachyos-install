#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/../basico/helpers.sh"
show_script_version "Teclado, mouse y touchpad" "${BASH_SOURCE[0]}"
[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."
step "Configurando dispositivos de entrada"
mkdir -p "$HOME/.config/hypr/conf.d"
printf 'Layout [us/latam/es] (latam): '
read -r layout
layout=${layout:-latam}
case "$layout" in us|latam|es) ;; *) die "Layout no valido: $layout" ;; esac
printf 'Velocidad del puntero [-1.0 a 1.0] (0): '
read -r sensitivity
sensitivity=${sensitivity:-0}
[[ $sensitivity =~ ^-?(0(\.[0-9]+)?|1(\.0+)?)$ ]] || die "Velocidad no valida"
touchpad=false
if grep -qiE 'touchpad|trackpad' /proc/bus/input/devices 2>/dev/null; then touchpad=true; fi
natural=false; tap=true; disable_typing=true
if $touchpad; then
    read -r -p 'Scroll natural [s/N]: ' answer; [[ $answer =~ ^[sS]$ ]] && natural=true
    read -r -p 'Tocar para hacer clic [S/n]: ' answer; [[ ! $answer =~ ^[nN]$ ]] || tap=false
    read -r -p 'Desactivar touchpad mientras se escribe [S/n]: ' answer; [[ ! $answer =~ ^[nN]$ ]] || disable_typing=false
fi
cat > "$HOME/.config/hypr/conf.d/entrada.conf" <<EOF_CONF
input {
    kb_layout = $layout
    follow_mouse = 1
    sensitivity = $sensitivity
    touchpad {
        natural_scroll = $natural
        tap-to-click = $tap
        disable_while_typing = $disable_typing
        clickfinger_behavior = true
    }
}
EOF_CONF
ok "Configuracion de entrada creada"
