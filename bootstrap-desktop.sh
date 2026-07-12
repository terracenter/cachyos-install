#!/bin/bash
# bootstrap-desktop.sh — Bootstrapper remoto para Fase 2 (desktop post-reboot, usuario normal)
# Uso (en el sistema ya instalado, como usuario normal):
#   curl -fsSL https://raw.githubusercontent.com/terracenter/cachyos-install/main/bootstrap-desktop.sh | bash
#
# Clona el repo completo a $HOME/cachyos-install y delega el control
# a install-desktop.sh (necesario porque los subscripts dependen de archivos
# reales en disco, ej. qtile/configs/, no se pueden streamear sueltos).

set -euo pipefail

REPO_URL="https://github.com/terracenter/cachyos-install.git"
REPO_BRANCH="main"
TARGET_DIR="$HOME/cachyos-install"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

die() {
    echo -e "\n   ${RED}ERROR${NC}  $1\n" >&2
    exit 1
}

ok() {
    echo -e "${GREEN}✓${NC} $1"
}

step() {
    echo -e "${CYAN}▶${NC} $1"
}

# Verificar que NO es root
[[ $EUID -eq 0 ]] && die "No ejecutes esto con sudo/root. Ejecuta como tu usuario normal."

echo -e "${CYAN}${BOLD}=== cachyos-install: bootstrap (Fase 2) ===${NC}\n"

# Verificar terminal interactiva (necesaria para el menú de install-desktop.sh)
if [[ ! -e /dev/tty ]]; then
    die "No se detectó una terminal interactiva (/dev/tty). Ejecuta este comando directamente en la consola del sistema instalado."
fi

# Instalar git si falta (en Fase 2, usuario normal con sudo disponible)
if ! command -v git >/dev/null 2>&1; then
    step "git no encontrado, instalando..."
    sudo pacman -Sy --noconfirm --needed git || die "No se pudo instalar git"
    ok "git instalado"
fi

# Idempotencia: directorio limpio siempre
if [[ -e "$TARGET_DIR" ]]; then
    step "Directorio $TARGET_DIR ya existe, limpiando para clone fresco..."
    rm -rf "$TARGET_DIR"
fi

step "Clonando cachyos-install ($REPO_BRANCH)..."
git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$TARGET_DIR" \
    || die "No se pudo clonar el repositorio. Verifica la conexión a internet."
ok "Repositorio clonado en $TARGET_DIR"

cd "$TARGET_DIR"

echo ""
step "Delegando a install-desktop.sh..."
echo ""

exec bash "$TARGET_DIR/install-desktop.sh"
