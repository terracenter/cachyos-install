#!/usr/bin/env bash

export NCURSES_NO_UTF8_ACS=1

# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ install.sh                                                                  │
# │ Punto de entrada único con menús estructurados e inteligentes              │
# └─────────────────────────────────────────────────────────────────────────────┘

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG_FILE="$SCRIPT_DIR/install.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

_on_error() {
    local exit_code=$?
    local line_no="${1:-desconocida}"
    local command="${2:-desconocido}"

    printf '\n%b✗ Fallo inesperado, línea %s: %s%b\n' \
        "${RED}${BOLD}" "$line_no" "$command" "$NC" >&2
    printf '   %bLog de instalación: %s%b\n' "$YELLOW" "$LOG_FILE" "$NC" >&2
    printf '%s FALLO código=%s línea=%s comando=%q\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$exit_code" "$line_no" "$command" \
        >> "$LOG_FILE"

    return "$exit_code"
}
trap '_on_error "$LINENO" "$BASH_COMMAND"' ERR

header() { printf '\n%b=== %s ===%b\n\n' "${CYAN}${BOLD}" "$1" "$NC"; }
step()   { printf '%b▶%b %s\n' "$BLUE" "$NC" "$1"; }
ok()     { printf '%b✓%b %s\n' "$GREEN" "$NC" "$1"; }
warn()   { printf '%b⚠%b %s\n' "$YELLOW" "$NC" "$1"; }
info()   { printf '%bℹ%b %s\n' "$CYAN" "$NC" "$1"; }
die()    { printf '\n   %bERROR%b  %s\n\n' "$RED" "$NC" "$1" >&2; exit 1; }

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "No se encontró el comando requerido: $1"
}

require_script() {
    [[ -f "$1" ]] || die "No existe el script requerido: $1"
    [[ -r "$1" ]] || die "No se puede leer el script requerido: $1"
}

install_whiptail_if_needed() {
    command -v whiptail >/dev/null 2>&1 && return 0

    command -v pacman >/dev/null 2>&1 || \
        die "whiptail no está instalado y pacman no está disponible."

    echo "Instalando whiptail (paquete libnewt)..."
    sudo pacman -S --needed --noconfirm libnewt || \
        die "No se pudo instalar libnewt. Actualiza el sistema e inténtalo nuevamente."

    command -v whiptail >/dev/null 2>&1 || \
        die "libnewt se instaló, pero whiptail continúa sin estar disponible."
}

prepare_system_and_mirrors() {
    step "Verificando conectividad a internet..."
    if ! ping -c 1 -W 3 archlinux.org >/dev/null 2>&1; then
        die "No hay conexión a Internet. Verifica la red antes de continuar."
    fi
    ok "Conexión a Internet activa"

    step "Validando repositorios y optimizando mirrors..."
    if ! command -v cachyos-rate-mirrors >/dev/null 2>&1; then
        step "Instalando cachyos-rate-mirrors..."
        sudo pacman -S --needed --noconfirm cachyos-rate-mirrors || \
            warn "No se pudo instalar cachyos-rate-mirrors"
    fi

    if command -v cachyos-rate-mirrors >/dev/null 2>&1; then
        sudo cachyos-rate-mirrors || \
            warn "cachyos-rate-mirrors falló; se usará la lista actual"
    fi

    if [[ -e /var/lib/pacman/db.lck ]]; then
        die "Existe /var/lib/pacman/db.lck. Verifica que no haya otro gestor de paquetes activo. No se eliminará automáticamente."
    fi

    step "Ejecutando actualización completa del sistema..."
    sudo pacman -Syu --noconfirm || \
        die "Falló la actualización preliminar del sistema."
    ok "Sistema y base de paquetes actualizados"
}

menu_base() {
    if ! whiptail --title "Fase 1: Instalación Base" --defaultno \
        --yesno "⚠ ADVERTENCIA CRÍTICA: esta opción FORMATEARÁ y BORRARÁ el disco seleccionado.\n\n¿Estás ABSOLUTAMENTE SEGURO de continuar?" 11 70; then
        warn "Instalación base cancelada por seguridad."
        return 0
    fi

    if ! whiptail --title "Confirmación final" --defaultno \
        --yesno "¿Reconfirmas que deseas continuar? Se perderán todos los datos del disco seleccionado." 10 70; then
        whiptail --title "Cancelado" --msgbox "Operación abortada por seguridad." 8 50
        return 0
    fi

    require_script "$SCRIPT_DIR/base/install-base.sh"

    step "Solicitando privilegios administrativos para la instalación base..."
    if ! sudo -v; then
        whiptail --title "Autenticación cancelada" \
            --msgbox "No se obtuvieron privilegios administrativos. No se realizó ningún cambio." 9 70
        return 0
    fi

    step "Iniciando instalación base..."
    if sudo --preserve-env=TERM,LANG,LC_ALL,NCURSES_NO_UTF8_ACS \
        bash "$SCRIPT_DIR/base/install-base.sh"; then
        whiptail --title "Éxito" \
            --msgbox "Instalación base completada. Reinicia el sistema." 8 60
    else
        whiptail --title "Error" \
            --msgbox "Instalación base cancelada o no completada. Revisa $LOG_FILE." 9 70
    fi
}

menu_hyprland() {
    while true; do
        local sub_choice
        sub_choice=$(whiptail --title "Entorno Hyprland (Wayland)" \
            --menu "Selecciona una opción:" 14 75 4 \
            "1" "Instalar Hyprland Base (Escritorio, nftables, Config)" \
            "2" "Instalar Apps de Hyprland (Gaming, Navegadores, Dev)" \
            "3" "Desinstalar Hyprland (Limpieza completa)" \
            "4" "Volver al menú principal" 3>&1 1>&2 2>&3) || return 0

        [[ "$sub_choice" == "4" ]] && return 0

        if [[ $EUID -eq 0 ]]; then
            whiptail --title "Error" \
                --msgbox "Esta operación debe ejecutarse como usuario normal, no como root." 8 70
            continue
        fi

        case "$sub_choice" in
            1)
                require_script "$SCRIPT_DIR/hyprland/install-hyprland-desktop.sh"
                prepare_system_and_mirrors
                step "Iniciando instalación de Hyprland Base..."
                if SKIP_SYSTEM_UPDATE=1 bash "$SCRIPT_DIR/hyprland/install-hyprland-desktop.sh"; then
                    whiptail --title "Éxito" --msgbox "Hyprland Base instalado correctamente." 8 60
                else
                    whiptail --title "Error" --msgbox "La instalación de Hyprland Base no se completó." 8 60
                fi
                ;;
            2)
                require_script "$SCRIPT_DIR/hyprland/install-hyprland-apps.sh"
                step "Instalando aplicaciones y gaming de Hyprland..."
                if SKIP_SYSTEM_UPDATE=1 bash "$SCRIPT_DIR/hyprland/install-hyprland-apps.sh"; then
                    whiptail --title "Éxito" --msgbox "Aplicaciones y gaming instalados correctamente." 8 60
                else
                    whiptail --title "Error" --msgbox "La instalación de aplicaciones no se completó." 8 60
                fi
                ;;
            3)
                require_script "$SCRIPT_DIR/hyprland/uninstall-hyprland-omarchy.sh"
                step "Desinstalando Hyprland..."
                if bash "$SCRIPT_DIR/hyprland/uninstall-hyprland-omarchy.sh"; then
                    whiptail --title "Éxito" --msgbox "Hyprland desinstalado correctamente." 8 55
                else
                    whiptail --title "Error" --msgbox "La desinstalación de Hyprland no se completó." 8 60
                fi
                ;;
        esac
    done
}

menu_qtile() {
    while true; do
        local sub_choice
        sub_choice=$(whiptail --title "Entorno Qtile (X11)" \
            --menu "Selecciona una opción:" 13 70 3 \
            "1" "Instalar Qtile (X11 + Modesetting Intel DRI3)" \
            "2" "Desinstalar Qtile (Limpieza completa X11)" \
            "3" "Volver al menú principal" 3>&1 1>&2 2>&3) || return 0

        [[ "$sub_choice" == "3" ]] && return 0

        if [[ $EUID -eq 0 ]]; then
            whiptail --title "Error" \
                --msgbox "Esta operación debe ejecutarse como usuario normal, no como root." 8 70
            continue
        fi

        case "$sub_choice" in
            1)
                require_script "$SCRIPT_DIR/qtile/install-qtile-omarchy.sh"
                prepare_system_and_mirrors
                step "Iniciando instalación de Qtile..."
                if bash "$SCRIPT_DIR/qtile/install-qtile-omarchy.sh"; then
                    whiptail --title "Éxito" --msgbox "Qtile instalado correctamente." 8 55
                else
                    whiptail --title "Error" --msgbox "La instalación de Qtile no se completó." 8 60
                fi
                ;;
            2)
                require_script "$SCRIPT_DIR/qtile/uninstall-qtile-omarchy.sh"
                step "Desinstalando Qtile y paquetes X11..."
                if bash "$SCRIPT_DIR/qtile/uninstall-qtile-omarchy.sh"; then
                    whiptail --title "Éxito" --msgbox "Qtile y los paquetes X11 fueron eliminados." 8 60
                else
                    whiptail --title "Error" --msgbox "La desinstalación de Qtile no se completó." 8 60
                fi
                ;;
        esac
    done
}

main() {
    require_command sudo
    install_whiptail_if_needed

    while true; do
        local main_choice
        main_choice=$(whiptail --title "CachyOS Installation Suite" \
            --menu "Punto de entrada único, menú interactivo" 16 80 5 \
            "1" "Instalación Base del Sistema (BTRFS / Formateo)" \
            "2" "Entorno de Escritorio: Hyprland (Wayland)" \
            "3" "Entorno de Escritorio: Qtile (X11)" \
            "4" "Suite de Aplicaciones Genéricas (QEMU, Ofimática)" \
            "5" "Salir" 3>&1 1>&2 2>&3) || main_choice="5"

        case "$main_choice" in
            1) menu_base ;;
            2) menu_hyprland ;;
            3) menu_qtile ;;
            4)
                if [[ $EUID -eq 0 ]]; then
                    whiptail --title "Error" \
                        --msgbox "La instalación de aplicaciones debe ejecutarse como usuario normal." 8 70
                    continue
                fi
                require_script "$SCRIPT_DIR/apps/install-apps.sh"
                step "Iniciando suite de aplicaciones genéricas..."
                if bash "$SCRIPT_DIR/apps/install-apps.sh"; then
                    whiptail --title "Éxito" --msgbox "Aplicaciones instaladas correctamente." 8 55
                else
                    whiptail --title "Error" --msgbox "La instalación de aplicaciones no se completó." 8 60
                fi
                ;;
            5)
                printf '\n%bOperación finalizada.%b\n' "$GREEN" "$NC"
                exit 0
                ;;
        esac
    done
}

main "$@"
