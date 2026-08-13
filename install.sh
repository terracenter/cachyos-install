#!/bin/bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ install.sh                                                                  │
# │ Punto de entrada ÚNICO e Inteligente para CachyOS Installation Suite       │
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

die() {
    echo -e "\n   ${RED}ERROR${NC}  $1\n" >&2
    exit 1
}

# ─── Banner Principal ─────────────────────────────────────────────────────────
header "CachyOS Installation Suite"
echo -e "${BOLD}Punto de entrada único — Instalador Inteligente de CachyOS${NC}"
echo "Soporta Instalación Base (BTRFS), Hyprland (Wayland), Qtile (X11) y Gaming"
echo ""

# ─── Menú Principal de Opciones ──────────────────────────────────────────────
echo -e "${BOLD}Selecciona la acción a realizar:${NC}"
echo "  1) Entorno de Escritorio: Hyprland (Wayland — Recomendado)"
echo "  2) Entorno de Escritorio: Qtile (X11 — Modesetting Intel DRI3)"
echo "  3) Instalación Base del Sistema (Particionado BTRFS / Formateo de Disco)"
echo "  4) Desinstalar Qtile / Limpiar paquetes X11"
echo "  5) Instalar Suite de Gaming (Steam, GameMode, MangoHud)"
echo "  6) Salir"
echo ""

read -p "Opción [1-6]: " main_choice < /dev/tty || main_choice="6"

case "$main_choice" in
    1)
        [[ $EUID -eq 0 ]] && die "La instalación de escritorio debe ejecutarse como usuario normal (no root)."
        step "Iniciando instalación de Hyprland (Wayland)..."
        bash "$SCRIPT_DIR/hyprland/install-cachyos-hyprland.sh" || die "Fallo en instalador base de Hyprland"
        SKIP_SYSTEM_UPDATE=1 bash "$SCRIPT_DIR/hyprland/install-hyprland-desktop.sh" || die "Fallo en configuración de Hyprland"
        ok "Escritorio Hyprland instalado y configurado con éxito"
        ;;

    2)
        [[ $EUID -eq 0 ]] && die "La instalación de escritorio debe ejecutarse como usuario normal (no root)."
        step "Iniciando instalación de Qtile (X11)..."
        bash "$SCRIPT_DIR/qtile/install-qtile-omarchy.sh" || die "Fallo en la instalación de Qtile"
        ok "Escritorio Qtile (X11) instalado y configurado con éxito"
        ;;

    3)
        # Advertencia Doble para evitar borrado accidental
        header "¡ADVERTENCIA CRÍTICA DE SEGURIDAD!"
        echo -e "${RED}${BOLD}⚠ ATENCIÓN: La Instalación Base SOBREESCRIBIRÁ y FORMATEARÁ el disco seleccionado.${NC}"
        echo -e "${RED}${BOLD}  Toda la información contenida en el disco SERÁ ELIMINADA PERMANENTEMENTE.${NC}\n"

        read -p "PRIMERA CONFIRMACIÓN: ¿Estás SEGURO de formatear el disco? [escribe 'DESTRUIR']: " confirm1 < /dev/tty || confirm1=""
        if [[ "$confirm1" != "DESTRUIR" ]]; then
            die "Instalación base cancelada por seguridad. Se requiere escribir 'DESTRUIR'."
        fi

        echo -e "\n${RED}${BOLD}⚠ SEGUNDA CONFIRMACIÓN FINAL:${NC}"
        read -p "¿Confirmas por segunda vez que estás en un Live ISO y deseas CONTINUAR? [s/N]: " confirm2 < /dev/tty || confirm2=""
        if [[ ! "$confirm2" =~ ^[sS]$ ]]; then
            die "Instalación base cancelada en la segunda confirmación."
        fi

        [[ $EUID -ne 0 ]] && die "La instalación base requiere ejecutarse como root (sudo ./install.sh)."

        step "Iniciando Instalación Base (Live ISO)..."
        bash "$SCRIPT_DIR/base/install-base.sh" || die "Fallo en la instalación base"
        ok "Instalación base completada exitosamente. Reinicia el sistema."
        ;;

    4)
        [[ $EUID -eq 0 ]] && die "La desinstalación debe ejecutarse como usuario normal (no root)."
        step "Desinstalando Qtile y paquetes X11..."
        bash "$SCRIPT_DIR/qtile/uninstall-qtile-omarchy.sh" || die "Fallo al desinstalar Qtile"
        ok "Qtile y paquetes X11 removidos con éxito"
        ;;

    5)
        [[ $EUID -eq 0 ]] && die "La instalación de gaming debe ejecutarse como usuario normal."
        step "Instalando herramientas de Gaming..."
        SKIP_SYSTEM_UPDATE=1 bash "$SCRIPT_DIR/gaming/install-gaming.sh" || die "Fallo en instalador de gaming"
        ok "Suite de Gaming instalada exitosamente"
        ;;

    6|*)
        info "Operación cancelada por el usuario."
        exit 0
        ;;
esac
