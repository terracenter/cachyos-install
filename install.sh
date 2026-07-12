#!/bin/bash
# install.sh — Fase 1: instalación base (Live ISO, root)
# Uso: sudo bash install.sh

set -e

# Colores y helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

# Verificar root
[[ $EUID -ne 0 ]] && die "Ejecutar como root (sudo bash install.sh)"

# Banner
header "CachyOS Installation Suite"
echo -e "${BOLD}Instalador automatizado para CachyOS${NC}"
echo "Soporta Hyprland (Wayland) y Qtile (X11)"
echo ""

# PASO 1: Instalación base (siempre)
step "Instalando base del sistema (BTRFS, bootloader, etc.)..."
bash "$(dirname "$0")/base/install-base.sh" || die "Base installation failed"
ok "Base del sistema instalada"

header "Instalación base completada"
echo -e "${GREEN}${BOLD}✓ Sistema base listo${NC}"
echo ""
echo "Próximos pasos:"
echo "  1. Reinicia: reboot"
echo "  2. Inicia sesión con el usuario que creaste"
echo "  3. Ejecuta el instalador de escritorio (Hyprland/Qtile/gaming):"
echo ""
echo -e "     ${BOLD}curl -fsSL https://raw.githubusercontent.com/terracenter/cachyos-install/main/bootstrap-desktop.sh | bash${NC}"
echo ""
