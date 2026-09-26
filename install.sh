#!/bin/bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ install.sh                                                                  │
# │ Punto de entrada ÚNICO con Menús Estructurados e Inteligentes              │
# └─────────────────────────────────────────────────────────────────────────────┘

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

_on_error() {
    echo -e "\n${RED}${BOLD}✗  Fallo inesperado — línea $1: $2${NC}" >&2
    echo -e "   ${YELLOW}Log de instalación: $LOG_FILE${NC}" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') FALLO línea $1: $2" >> "$LOG_FILE"
}
trap '_on_error $LINENO "$BASH_COMMAND"' ERR

header() {
    echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}\n"
}

step() {
    echo -e "${BLUE}▶${NC} $1"
}

ok() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

die() {
    echo -e "\n   ${RED}ERROR${NC}  $1\n" >&2
    exit 1
}

# ─── Validación de Conexión, Mirrors y Actualización de Sistema ─────────────
prepare_system_and_mirrors() {
    step "Verificando conectividad a internet..."
    if ! ping -c 1 -W 3 archlinux.org &>/dev/null; then
        die "No hay conexión a Internet. Verifica la red antes de continuar."
    fi
    ok "Conexión a Internet activa"

    step "Validando repositorios y optimizando velocidad de mirrors..."
    if ! command -v cachyos-rate-mirrors &>/dev/null; then
        step "Instalando cachyos-rate-mirrors..."
        sudo pacman -S --noconfirm cachyos-rate-mirrors || warn "No se pudo instalar cachyos-rate-mirrors"
    fi
    sudo cachyos-rate-mirrors \
        || warn "cachyos-rate-mirrors falló — usando lista de mirrors actual"

    step "Ejecutando actualización completa del sistema antes de instalar..."
    # Desbloquear lock de pacman si quedó huérfano
    local lock="/var/lib/pacman/db.lck"
    if [[ -f "$lock" ]]; then
        if ! pgrep -x pacman &>/dev/null; then
            sudo rm -f "$lock"
        fi
    fi
    sudo pacman -Syu --noconfirm || die "Falló la actualización preliminar del sistema."
    ok "Sistema y base de paquetes 100% actualizados"
}
menu_base() {
    if ! whiptail --title "Fase 1: Instalación Base" --yesno "⚠ ADVERTENCIA CRÍTICA: Esta opción FORMATEARÁ y BORRARÁ el disco seleccionado.\n\n¿Estás seguro de continuar?" 10 60; then
        warn "Instalación base cancelada por seguridad."
        return 0
    fi

    confirm1=$(whiptail --title "Confirmación de Destrucción" --inputbox "Escribe la palabra 'DESTRUIR' en mayúsculas para formatear el disco:" 10 60 3>&1 1>&2 2>&3)
    if [[ "$confirm1" != "DESTRUIR" ]]; then
        whiptail --title "Cancelado" --msgbox "La palabra clave no coincide. Operación abortada por seguridad." 8 50
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        whiptail --title "Error de Privilegios" --msgbox "La instalación base requiere ejecutarse como root (sudo ./install.sh)." 8 60
        return 0
    fi

    step "Iniciando Instalación Base..."
    if bash "$SCRIPT_DIR/base/install-base.sh"; then
        whiptail --title "Éxito" --msgbox "Instalación base completada exitosamente. Reinicia el sistema." 8 60
    else
        whiptail --title "Error" --msgbox "Instalación base cancelada o no completada." 8 50
    fi
}

# ─── SUBMENÚ 2: HYPRLAND (WAYLAND) ────────────────────────────────────────────
menu_hyprland() {
    while true; do
        sub_choice=$(whiptail --title "Entorno Hyprland (Wayland)" --menu "Selecciona una opción:" 14 75 4 \
            "1" "Instalar Hyprland Base (Escritorio, nftables, Config)" \
            "2" "Instalar Apps de Hyprland (Gaming, Navegadores, Dev)" \
            "3" "Desinstalar Hyprland (Limpieza completa)" \
            "4" "Volver al menú principal" 3>&1 1>&2 2>&3)

        if [[ -z "$sub_choice" || "$sub_choice" == "4" ]]; then
            return 0
        fi

        case "$sub_choice" in
            1)
                if [[ $EUID -eq 0 ]]; then
                    whiptail --title "Error" --msgbox "La instalación de escritorio debe ejecutarse como usuario normal (no root)." 8 70
                    return 0
                fi
                prepare_system_and_mirrors
                step "Iniciando instalación de Hyprland Base..."
                if SKIP_SYSTEM_UPDATE=1 bash "$SCRIPT_DIR/hyprland/install-hyprland-desktop.sh"; then
                    whiptail --title "Éxito" --msgbox "Escritorio Hyprland Base instalado y configurado con éxito" 8 60
                else
                    whiptail --title "Error" --msgbox "Instalación de Hyprland Base cancelada o no completada." 8 60
                fi
                ;;
            2)
                if [[ $EUID -eq 0 ]]; then
                    whiptail --title "Error" --msgbox "La instalación de aplicaciones debe ejecutarse como usuario normal (no root)." 8 70
                    return 0
                fi
                step "Instalando Suite de Aplicaciones y Gaming de Hyprland..."
                if SKIP_SYSTEM_UPDATE=1 bash "$SCRIPT_DIR/hyprland/install-hyprland-apps.sh"; then
                    whiptail --title "Éxito" --msgbox "Aplicaciones y Gaming instalados con éxito" 8 50
                else
                    whiptail --title "Error" --msgbox "Instalación de aplicaciones cancelada o no completada." 8 60
                fi
                ;;
            3)
                if [[ $EUID -eq 0 ]]; then
                    whiptail --title "Error" --msgbox "La desinstalación debe ejecutarse como usuario normal (no root)." 8 70
                    return 0
                fi
                step "Desinstalando Hyprland..."
                if bash "$SCRIPT_DIR/hyprland/uninstall-hyprland-omarchy.sh"; then
                    whiptail --title "Éxito" --msgbox "Hyprland desinstalado exitosamente" 8 50
                else
                    whiptail --title "Error" --msgbox "Desinstalación de Hyprland cancelada o no completada." 8 60
                fi
                ;;
        esac
    done
}

# ─── SUBMENÚ 3: QTILE (X11) ───────────────────────────────────────────────────
menu_qtile() {
    while true; do
        sub_choice=$(whiptail --title "Entorno Qtile (X11)" --menu "Selecciona una opción:" 13 70 3 \
            "1" "Instalar Qtile (X11 + Modesetting Intel DRI3)" \
            "2" "Desinstalar Qtile (Limpieza completa X11)" \
            "3" "Volver al menú principal" 3>&1 1>&2 2>&3)

        if [[ -z "$sub_choice" || "$sub_choice" == "3" ]]; then
            return 0
        fi

        case "$sub_choice" in
            1)
                if [[ $EUID -eq 0 ]]; then
                    whiptail --title "Error" --msgbox "La instalación debe ejecutarse como usuario normal (no root)." 8 70
                    return 0
                fi
                prepare_system_and_mirrors
                step "Iniciando instalación de Qtile (X11)..."
                if bash "$SCRIPT_DIR/qtile/install-qtile-omarchy.sh"; then
                    whiptail --title "Éxito" --msgbox "Escritorio Qtile (X11) instalado y configurado con éxito" 8 60
                else
                    whiptail --title "Error" --msgbox "Instalación de Qtile cancelada o no completada." 8 60
                fi
                ;;
            2)
                if [[ $EUID -eq 0 ]]; then
                    whiptail --title "Error" --msgbox "La desinstalación debe ejecutarse como usuario normal (no root)." 8 70
                    return 0
                fi
                step "Desinstalando Qtile y paquetes X11..."
                if bash "$SCRIPT_DIR/qtile/uninstall-qtile-omarchy.sh"; then
                    whiptail --title "Éxito" --msgbox "Qtile y paquetes X11 removidos con éxito" 8 60
                else
                    whiptail --title "Error" --msgbox "Desinstalación de Qtile cancelada o no completada." 8 60
                fi
                ;;
        esac
    done
}

# ─── MENÚ PRINCIPAL ───────────────────────────────────────────────────────────
main() {
    # Verificar whiptail
    if ! command -v whiptail &>/dev/null; then
        echo "Instalando whiptail (newt) para la interfaz gráfica..."
        sudo pacman -Sy --noconfirm libnewt &>/dev/null || true
    fi

    while true; do
        main_choice=$(whiptail --title "CachyOS Installation Suite" --menu "Punto de Entrada Único — Menú Interactivo" 16 80 5 \
            "1" "Instalación Base del Sistema (BTRFS / Formateo)" \
            "2" "Entorno de Escritorio: Hyprland (Wayland)" \
            "3" "Entorno de Escritorio: Qtile (X11)" \
            "4" "Suite de Aplicaciones Genéricas (QEMU, Ofimática)" \
            "5" "Salir" 3>&1 1>&2 2>&3)

        if [[ -z "$main_choice" || "$main_choice" == "5" ]]; then
            echo -e "\n${GREEN}Operación finalizada.${NC}"
            exit 0
        fi

        case "$main_choice" in
            1) menu_base ;;
            2) menu_hyprland ;;
            3) menu_qtile ;;
            4)
                if [[ $EUID -eq 0 ]]; then
                    whiptail --title "Error" --msgbox "La instalación de aplicaciones debe ejecutarse como usuario normal." 8 70
                else
                    step "Iniciando Suite de Aplicaciones Genéricas..."
                    if bash "$SCRIPT_DIR/apps/install-apps.sh"; then
                        whiptail --title "Éxito" --msgbox "Aplicaciones instaladas exitosamente" 8 50
                    else
                        whiptail --title "Error" --msgbox "Instalación de aplicaciones cancelada o no completada." 8 60
                    fi
                fi
                ;;
        esac
    done
}

main
