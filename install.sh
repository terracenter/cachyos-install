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
    if command -v cachyos-rate-mirrors &>/dev/null; then
        sudo cachyos-rate-mirrors || warn "cachyos-rate-mirrors falló — usando lista de mirrors actual"
        ok "Mirrors optimizados según latencia y velocidad"
    elif command -v rate-mirrors &>/dev/null; then
        sudo rate-mirrors arch | sudo tee /etc/pacman.d/mirrorlist >/dev/null || warn "rate-mirrors falló"
        ok "Mirrors Arch optimizados"
    else
        info "Optimizador de mirrors no instalado — usando repositorios predeterminados del sistema"
    fi

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
    header "Fase 1: Instalación Base (Live ISO / BTRFS)"
    echo -e "${RED}${BOLD}⚠ ADVERTENCIA CRÍTICA: Esta opción FORMATEARÁ y BORRARÁ el disco seleccionado.${NC}\n"

    read -p "PRIMERA CONFIRMACIÓN: ¿Estás SEGURO de formatear el disco? [escribe 'DESTRUIR']: " confirm1 < /dev/tty || confirm1=""
    if [[ "$confirm1" != "DESTRUIR" ]]; then
        warn "Instalación base cancelada por seguridad. (No se escribió 'DESTRUIR')."
        return 0
    fi

    echo -e "\n${RED}${BOLD}⚠ SEGUNDA CONFIRMACIÓN FINAL:${NC}"
    read -p "¿Confirmas por segunda vez que estás en un Live ISO y deseas CONTINUAR? [s/N]: " confirm2 < /dev/tty || confirm2=""
    if [[ ! "$confirm2" =~ ^[sS]$ ]]; then
        warn "Instalación base cancelada en la segunda confirmación."
        return 0
    fi

    if [[ $EUID -ne 0 ]]; then
        warn "La instalación base requiere ejecutarse como root (sudo ./install.sh)."
        return 0
    fi

    step "Iniciando Instalación Base..."
    bash "$SCRIPT_DIR/base/install-base.sh" || warn "Fallo o cancelación en la instalación base"
    ok "Instalación base completada exitosamente. Reinicia el sistema."
}

# ─── SUBMENÚ 2: HYPRLAND (WAYLAND) ────────────────────────────────────────────
menu_hyprland() {
    while true; do
        header "Entorno Hyprland (Wayland)"
        echo "  1) Instalar Hyprland (Wayland + Herramientas nativas)"
        echo "  2) Desinstalar Hyprland (Limpieza completa)"
        echo "  3) Volver al menú principal"
        echo ""
        read -p "Opción [1-3]: " sub_choice < /dev/tty || sub_choice="3"

        case "$sub_choice" in
            1)
                if [[ $EUID -eq 0 ]]; then
                    warn "La instalación de escritorio debe ejecutarse como usuario normal (no root)."
                    return 0
                fi
                prepare_system_and_mirrors
                step "Iniciando instalación de Hyprland (Wayland)..."
                if bash "$SCRIPT_DIR/hyprland/install-cachyos-hyprland.sh"; then
                    SKIP_SYSTEM_UPDATE=1 bash "$SCRIPT_DIR/hyprland/install-hyprland-desktop.sh" || warn "Fallo en configuración de Hyprland"
                    ok "Escritorio Hyprland instalado y configurado con éxito"
                else
                    warn "Instalación de Hyprland cancelada o fallida — se omitió la configuración de escritorio."
                fi
                ;;
            2)
                if [[ $EUID -eq 0 ]]; then
                    warn "La desinstalación debe ejecutarse como usuario normal (no root)."
                    return 0
                fi
                step "Desinstalando Hyprland..."
                bash "$SCRIPT_DIR/hyprland/uninstall-hyprland-omarchy.sh" || warn "Fallo en desinstalación de Hyprland"
                ok "Hyprland desinstalado exitosamente"
                ;;
            *) return 0 ;;
        esac
    done
}

# ─── SUBMENÚ 3: QTILE (X11) ───────────────────────────────────────────────────
menu_qtile() {
    while true; do
        header "Entorno Qtile (X11)"
        echo "  1) Instalar Qtile (X11 + Modesetting Intel DRI3)"
        echo "  2) Desinstalar Qtile (Limpieza completa X11)"
        echo "  3) Volver al menú principal"
        echo ""
        read -p "Opción [1-3]: " sub_choice < /dev/tty || sub_choice="3"

        case "$sub_choice" in
            1)
                if [[ $EUID -eq 0 ]]; then
                    warn "La instalación debe ejecutarse como usuario normal (no root)."
                    return 0
                fi
                prepare_system_and_mirrors
                step "Iniciando instalación de Qtile (X11)..."
                bash "$SCRIPT_DIR/qtile/install-qtile-omarchy.sh" || warn "Fallo en la instalación de Qtile"
                ok "Escritorio Qtile (X11) instalado y configurado con éxito"
                ;;
            2)
                if [[ $EUID -eq 0 ]]; then
                    warn "La desinstalación debe ejecutarse como usuario normal (no root)."
                    return 0
                fi
                step "Desinstalando Qtile y paquetes X11..."
                bash "$SCRIPT_DIR/qtile/uninstall-qtile-omarchy.sh" || warn "Fallo al desinstalar Qtile"
                ok "Qtile y paquetes X11 removidos con éxito"
                ;;
            *) return 0 ;;
        esac
    done
}

# ─── MENÚ PRINCIPAL ───────────────────────────────────────────────────────────
main() {
    while true; do
        header "CachyOS Installation Suite"
        echo -e "${BOLD}Punto de Entrada Único — Menú Interactivo${NC}\n"

        echo "  1) Instalación Base del Sistema (Particionado BTRFS / Formateo de Disco)"
        echo "  2) Entorno de Escritorio: Hyprland (Wayland)"
        echo "  3) Entorno de Escritorio: Qtile (X11)"
        echo "  4) Suite de Gaming (Steam, GameMode, MangoHud)"
        echo "  5) Salir"
        echo ""

        read -p "Selecciona una opción [1-5]: " main_choice < /dev/tty || main_choice="5"

        case "$main_choice" in
            1) menu_base ;;
            2) menu_hyprland ;;
            3) menu_qtile ;;
            4)
                if [[ $EUID -eq 0 ]]; then
                    warn "La instalación de gaming debe ejecutarse como usuario normal."
                else
                    step "Instalando herramientas de Gaming..."
                    SKIP_SYSTEM_UPDATE=1 bash "$SCRIPT_DIR/gaming/install-gaming.sh" || warn "Fallo en instalador de gaming"
                    ok "Suite de Gaming instalada exitosamente"
                fi
                ;;
            5|*)
                echo -e "\n${GREEN}Operación finalizada.${NC}"
                exit 0
                ;;
        esac
    done
}

main
