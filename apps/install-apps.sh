#!/usr/bin/env bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ apps/install-apps.sh                                                        │
# │ Suite de Aplicaciones Opcionales (Desarrollo, QEMU, Ofimática, CUPS, Sync)    │
# └─────────────────────────────────────────────────────────────────────────────┘

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

header() {
    echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    printf "${BOLD}${BLUE}║  %-52s║${NC}\n" "$1"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
}

step()  { echo -e "\n${BOLD}▶  $1${NC}"; }
ok()    { echo -e "   ${GREEN}✓  $1${NC}"; }
warn()  { echo -e "   ${YELLOW}⚠  $1${NC}"; }
info()  { echo -e "   ${CYAN}ℹ  $1${NC}"; }
die()   { echo -e "\n   ${RED}✗  $1${NC}\n" >&2; exit 1; }

confirm() {
    printf "\n${CYAN}   %s [s/N]: ${NC}" "$1"
    read -r _resp < /dev/tty || _resp=""
    [[ "$_resp" =~ ^[sS]$ ]]
}

paru_install() {
    local pkgs=("$@")
    local to_install=()
    for p in "${pkgs[@]}"; do
        pacman -Qq "$p" &>/dev/null || to_install+=("$p")
    done
    [[ ${#to_install[@]} -eq 0 ]] && return 0

    info "Instalando paquetes: ${to_install[*]}"
    paru -S --needed --noconfirm --skipreview "${to_install[@]}"
}

# ─── Listas de paquetes opcionales ────────────────────────────────────────────

PKGS_DEV_OFFICIAL=(
    neovim lazygit github-cli rust llvm clang
    dotnet-runtime-9.0 ruby luarocks mise tree-sitter-cli
    python-poetry-core python-terminaltexteffects python-gobject
    mariadb-libs postgresql-libs libqalculate libyaml libsecret
    docker docker-buildx docker-compose lazydocker ufw-docker
)
PKGS_DEV_AUR=(
    visual-studio-code-bin
)

PKGS_QEMU_OFFICIAL=(qemu-full virt-manager swtpm)

PKGS_OFFICE_OFFICIAL=(libreoffice-fresh evince xournalpp pinta gnome-calculator)
PKGS_OFFICE_AUR=(obsidian typora)

PKGS_PRINT_OFFICIAL=(cups cups-browsed cups-filters cups-pdf system-config-printer)

PKGS_SYNC_AUR=(dropbox megasync-bin)

PKGS_BROWSERS_OFFICIAL=(firefox)
PKGS_BROWSERS_AUR=(google-chrome brave-bin opera microsoft-edge-stable-bin)

PKGS_SECURITY_OFFICIAL=(nftables lynis nmap wireshark-qt tcpdump netcat socat)

# ─── Menú de Selección ────────────────────────────────────────────────────────

main() {
    header "Suite de Aplicaciones Opcionales"

    [[ $EUID -ne 0 ]] || die "No ejecutes este script como root. Usa tu usuario normal."
    command -v paru &>/dev/null || die "paru no está disponible. Instala primero el escritorio."

    local INSTALL_DEV=false
    local INSTALL_QEMU=false
    local INSTALL_OFFICE=false
    local INSTALL_PRINT=false
    local INSTALL_SYNC=false
    local INSTALL_SECURITY=false
    local INSTALL_BROWSERS=()

    confirm "Herramientas de desarrollo (neovim, VSCode, rust, docker, lazygit...)" && INSTALL_DEV=true
    confirm "Virtualización QEMU/VMM (qemu-full, virt-manager, swtpm)"             && INSTALL_QEMU=true
    confirm "Suite ofimática (LibreOffice, Obsidian, Typora, Evince)"               && INSTALL_OFFICE=true
    confirm "Impresión (CUPS, system-config-printer)"                               && INSTALL_PRINT=true
    confirm "Sincronización en la Nube (Dropbox, Megasync)"                         && INSTALL_SYNC=true
    confirm "Seguridad y Hardening (nftables, lynis, nmap, wireshark, tcpdump, socat)" && INSTALL_SECURITY=true

    echo -e "\n${BOLD}Navegadores adicionales:${NC}"
    for b in "${PKGS_BROWSERS_OFFICIAL[@]}" "${PKGS_BROWSERS_AUR[@]}"; do
        confirm "  Instalar $b" && INSTALL_BROWSERS+=("$b")
    done

    echo -e "\n${BOLD}Resumen de Selección:${NC}"
    $INSTALL_DEV      && info "✓ Desarrollo (neovim, VSCode, rust, docker...)"
    $INSTALL_QEMU     && info "✓ Virtualización QEMU/VMM"
    $INSTALL_OFFICE   && info "✓ Ofimática (LibreOffice, Obsidian, Typora)"
    $INSTALL_PRINT    && info "✓ Impresión (CUPS)"
    $INSTALL_SYNC     && info "✓ Sincronización en la Nube (Dropbox, Megasync)"
    $INSTALL_SECURITY && info "✓ Seguridad y Hardening (nftables, lynis, nmap, wireshark, tcpdump, socat)"
    [[ ${#INSTALL_BROWSERS[@]} -gt 0 ]] && info "✓ Navegadores: ${INSTALL_BROWSERS[*]}"

    confirm "¿Proceder con la instalación de los paquetes seleccionados?" || die "Instalación de aplicaciones cancelada."

    step "Instalando paquetes seleccionados..."
    
    if $INSTALL_DEV; then
        step "Instalando Herramientas de Desarrollo..."
        paru_install "${PKGS_DEV_OFFICIAL[@]}" "${PKGS_DEV_AUR[@]}"
        sudo systemctl enable --now docker.service 2>/dev/null || true
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        ok "Desarrollo y Docker configurados"
    fi

    if $INSTALL_QEMU; then
        step "Instalando QEMU y Virtualización..."
        paru_install "${PKGS_QEMU_OFFICIAL[@]}"
        sudo systemctl enable --now libvirtd.service 2>/dev/null || true
        sudo usermod -aG libvirt "$USER" 2>/dev/null || true
        ok "QEMU y libvirtd configurados"
    fi

    if $INSTALL_OFFICE; then
        step "Instalando Suite Ofimática..."
        paru_install "${PKGS_OFFICE_OFFICIAL[@]}" "${PKGS_OFFICE_AUR[@]}"
        ok "Ofimática instalada"
    fi

    if $INSTALL_PRINT; then
        step "Instalando Servicio de Impresión (CUPS)..."
        paru_install "${PKGS_PRINT_OFFICIAL[@]}"
        sudo systemctl enable --now cups.service 2>/dev/null || true
        sudo usermod -aG lp "$USER" 2>/dev/null || true
        ok "CUPS habilitado"
    fi

    if $INSTALL_SYNC; then
        step "Instalando Sincronización en la Nube..."
        paru_install "${PKGS_SYNC_AUR[@]}"
        ok "Dropbox / Megasync instalados"
    fi

    if $INSTALL_SECURITY; then
        step "Instalando Suite de Seguridad y Hardening..."
        paru_install "${PKGS_SECURITY_OFFICIAL[@]}"
        sudo systemctl enable --now nftables.service 2>/dev/null || true
        sudo usermod -aG wireshark "$USER" 2>/dev/null || true
        ok "nftables nativo y herramientas de red/captura instaladas"

        local smng_path="/home/freddy/Workspace/Desarrollo/Security-Manager-NG"
        if [[ -d "$smng_path" ]]; then
            info "Security-Manager-NG detectado en $smng_path (en desarrollo activo)"
        else
            info "Security-Manager-NG se integrará cuando finalice su fase de desarrollo"
        fi
    fi

    if [[ ${#INSTALL_BROWSERS[@]} -gt 0 ]]; then
        step "Instalando Navegadores Seleccionados..."
        paru_install "${INSTALL_BROWSERS[@]}"
        ok "Navegadores instalados"
    fi

    ok "Suite de aplicaciones completada exitosamente."
}

main "$@"
