#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BASIC_DIR="$SCRIPT_DIR/install/basico"
CONFIG_DIR="$SCRIPT_DIR/install/configuracion"
LOG_FILE="$SCRIPT_DIR/install-hyprland-desktop.log"

# shellcheck source=install/basico/helpers.sh
source "$BASIC_DIR/helpers.sh"

show_script_version "Instalador Hyprland Base" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este instalador como usuario normal, no como root."

run_module() {
    local module="$1"

    [[ -f "$module" ]] || die "Modulo no encontrado: $module"

    step "Ejecutando $(basename "$module")"
    if bash "$module" > >(tee -a "$LOG_FILE") 2>&1; then
        ok "Modulo completado: $(basename "$module")"
    else
        local exit_code=$?
        die "Fallo $(basename "$module") con codigo $exit_code. Log: $LOG_FILE"
    fi
}

main() {
    : > "$LOG_FILE"
    header "Instalacion base de Hyprland"

    run_module "$BASIC_DIR/core.sh"
    run_module "$BASIC_DIR/navegacion.sh"
    run_module "$BASIC_DIR/top-bar.sh"
    run_module "$BASIC_DIR/hotkeys.sh"
    run_module "$CONFIG_DIR/monitores.sh"
    run_module "$CONFIG_DIR/teclado-mouse.sh"
    run_module "$CONFIG_DIR/audio.sh"
    run_module "$CONFIG_DIR/sddm.sh"

    header "Hyprland base instalado"
    info "La instalacion de aplicaciones opcionales se realiza por separado."
    info "Reinicia el equipo y selecciona la sesion Hyprland en el inicio de sesion."
}

main "$@"
