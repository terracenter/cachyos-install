#!/bin/bash
# install-desktop.sh — Fase 2: entorno de escritorio + gaming (post-reboot, usuario normal)
# Uso: bash install-desktop.sh (después de reboot en el sistema instalado)

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

# Verificar que NO es root
[[ $EUID -eq 0 ]] && die "No ejecutes este script como root. Ejecuta con tu usuario normal (sudo se usa internamente donde haga falta)."

# Banner
header "CachyOS Installation Suite — Fase 2 (Desktop)"
echo -e "${BOLD}Instalador de escritorio y gaming (post-reboot)${NC}"
echo "Soporta Hyprland (Wayland) y Qtile (X11)"
echo ""

# PASO 2: Elegir entorno de escritorio
header "Seleccionar entorno de escritorio"
echo "  1) Hyprland — Wayland (recomendado si tus apps lo soportan)"
echo "  2) Qtile    — X11 (para apps que aún no soportan Wayland)"
echo ""
read -p "Opción [1-2]: " choice < /dev/tty

case "$choice" in
    1)
        step "Instalando Hyprland..."
        bash "$(dirname "$0")/hyprland/install-cachyos-hyprland.sh" || die "Hyprland installation failed"
        ok "Hyprland instalado"

        step "Configurando escritorio Hyprland..."
        SKIP_SYSTEM_UPDATE=1 bash "$(dirname "$0")/hyprland/install-hyprland-desktop.sh" || die "Hyprland desktop installation failed"
        ok "Escritorio Hyprland configurado"
        ;;
    2)
        step "Instalando Qtile..."
        bash "$(dirname "$0")/qtile/install-qtile-omarchy.sh" || die "Qtile installation failed"
        ok "Qtile instalado"
        ;;
    *)
        die "Opción inválida. Elige 1 o 2."
        ;;
esac

# PASO 3: Gaming (opcional)
header "Herramientas de gaming"
read -p "¿Instalar gaming (Steam, GameMode, MangoHud, Proton-GE)? [s/N]: " gaming_choice < /dev/tty

if [[ "$gaming_choice" =~ ^[sS]$ ]]; then
    step "Instalando herramientas de gaming..."
    SKIP_SYSTEM_UPDATE=1 bash "$(dirname "$0")/gaming/install-gaming.sh" || die "Gaming installation failed"
    ok "Gaming instalado"
else
    ok "Gaming saltado"
fi

# Fin
header "Instalación completada"
echo -e "${GREEN}${BOLD}✓ CachyOS está listo${NC}"
echo ""
warn "Reiniciando en 5 segundos (Ctrl+C para cancelar)..."
sleep 5
sudo reboot
