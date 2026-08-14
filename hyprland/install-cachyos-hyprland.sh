#!/bin/bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ install-cachyos-hyprland.sh                                                 │
# │ Instalación del entorno gráfico Hyprland para CachyOS                      │
# │                                                                             │
# │ Inspirado en el trabajo de:                                                 │
# │   DHH           — github.com/basecamp/omarchy                               │
# │   mroboff        — github.com/mroboff/omarchy-on-cachyos                   │
# └─────────────────────────────────────────────────────────────────────────────┘

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install-cachyos-hyprland.log"

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Trap de error inesperado ─────────────────────────────────────────────────
_on_error() {
    echo -e "\n${RED}${BOLD}✗  Fallo inesperado — línea $1: $2${NC}" >&2
    echo -e "   ${YELLOW}Log: $LOG_FILE${NC}" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') FALLO línea $1: $2" >> "$LOG_FILE"
}
trap '_on_error $LINENO "$BASH_COMMAND"' ERR

# ─── Helpers ──────────────────────────────────────────────────────────────────
header() {
    echo -e "\n${BOLD}${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
    printf "${BOLD}${BLUE}║  %-52s║${NC}\n" "$1"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
}

step()  { echo -e "\n${BOLD}▶  $1${NC}"; }
ok()    { echo -e "   ${GREEN}✓  $1${NC}"; }
warn()  { echo -e "   ${YELLOW}⚠  $1${NC}"; }
info()  { echo -e "   ${DIM}→  $1${NC}"; }
die()   { echo -e "\n   ${RED}✗  $1${NC}\n" >&2; exit 1; }

confirm() {
    printf "\n${CYAN}   %s [s/N]: ${NC}" "$1"
    read -r _resp
    [[ "$_resp" =~ ^[sS]$ ]]
}

ensure_pacman_unlocked() {
    local lock="/var/lib/pacman/db.lck"
    [[ -f "$lock" ]] || return 0
    if pgrep -x pacman &>/dev/null; then
        die "Pacman está en ejecución. Espera a que termine antes de continuar."
    fi
    warn "Lock de pacman detectado sin proceso activo — limpiando..."
    sudo rm -f "$lock"
    ok "Lock de pacman eliminado"
}

# ─── Variables globales ───────────────────────────────────────────────────────
GPU_TYPE=""
GPU_PKGS_OFFICIAL=()
GPU_PKGS_AUR=()
AUR_CMD=""

INSTALL_BROWSERS=()
INSTALL_DEV=false
INSTALL_QEMU=false
INSTALL_OFFICE=false
INSTALL_PRINT=false
INSTALL_SYNC=false
FILE_MANAGER=""

# ─── Paquetes base (siempre se instalan) ──────────────────────────────────────

PKGS_HYPRLAND=(
    hyprland hypridle hyprlock hyprpicker hyprsunset
    hyprland-guiutils hyprland-preview-share-picker
    uwsm xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    xdg-terminal-exec qt5-wayland wl-clipboard cliphist
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
)

PKGS_BAR=(
    waybar mako swayosd swaybg rofi-wayland
)

PKGS_DM=(
    sddm polkit-gnome gnome-keyring
)

PKGS_TERMINAL=(
    alacritty starship zoxide fzf zsh zsh-completions
    zsh-syntax-highlighting zsh-autosuggestions
)

PKGS_SYSTEM=(
    btop fastfetch inxi kernel-modules-hook
    brightnessctl pamixer playerctl ufw
    man-db less unzip plocate expac whois inetutils
    tzupdate wireless-regdb alsa-utils avahi nss-mdns
    bluez blueman plymouth cachyos-plymouth-theme
)

PKGS_FILES=(
    nautilus nautilus-python gnome-disk-utility
    dosfstools exfatprogs gvfs-mtp gvfs-nfs gvfs-smb
)

PKGS_FONTS=(
    noto-fonts noto-fonts-cjk noto-fonts-emoji
    ttf-ia-writer ttf-jetbrains-mono-nerd
)

PKGS_THEMES=(
    gnome-themes-extra kvantum-qt5 papirus-icon-theme fontconfig
    catppuccin-gtk-theme-mocha catppuccin-cursors-mocha nwg-look
    eww dart-sass
)

PKGS_CAPTURE=(
    grim slurp satty jq gpu-screen-recorder obs-studio
)

PKGS_MEDIA=(
    mpv imv imagemagick ffmpegthumbnailer sushi cliamp
)

PKGS_COMMS=(
    signal-desktop localsend
)

PKGS_OCR=(
    tesseract tesseract-data-eng
)

PKGS_CLI=(
    ripgrep fd bat eza dust jq gum xmlstarlet usage
    bluetui bolt impala wiremix socat
)

# AUR base
PKGS_AUR_BASE=(
    sddm-astronaut-theme woff2-font-awesome
)

INSTALL_SPOTIFY=false

# ─── Paquetes opcionales ──────────────────────────────────────────────────────

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

# ─── GPU drivers ─────────────────────────────────────────────────────────────

PKGS_GPU_INTEL=(intel-media-driver mesa vulkan-intel libva-utils)
PKGS_GPU_AMD=(mesa vulkan-radeon libva-mesa-driver)
PKGS_GPU_NVIDIA=(nvidia-open nvidia-utils)

# ─── 1. Verificaciones previas ────────────────────────────────────────────────

check_prereqs() {
    header "Verificando requisitos"

    [[ $EUID -ne 0 ]] || die "No ejecutes el script como root. Usa tu usuario normal."
    ok "Usuario normal: $(whoami)"

    sudo -v 2>/dev/null || die "Este usuario no tiene privilegios sudo."
    ok "Privilegios sudo disponibles"

    local fstype
    fstype=$(findmnt -n -o FSTYPE /) || die "No se pudo detectar el sistema de archivos raíz."
    [[ "$fstype" == "btrfs" ]] || die "El sistema de archivos raíz no es BTRFS (encontrado: $fstype)."
    ok "Sistema de archivos raíz: BTRFS"

    command -v snapper &>/dev/null || die "snapper no está instalado. Ejecuta: sudo pacman -S snapper"
    if ! sudo snapper -c root list &>/dev/null; then
        info "Creando configuración snapper para root..."
        sudo mkdir -p /etc/snapper/configs
        # Crear el subvolumen solo si no existe (puede existir del particionado BTRFS)
        if ! sudo btrfs subvolume show /.snapshots &>/dev/null; then
            sudo btrfs subvolume create /.snapshots \
                || die "No se pudo crear el subvolumen /.snapshots"
        fi
        sudo tee /etc/snapper/configs/root > /dev/null << 'SNAPPER_EOF'
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"
ALLOW_USERS=""
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"
TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
SNAPPER_EOF
        sudo chmod 750 /.snapshots
        ok "snapper configurado automáticamente"
    else
        ok "snapper disponible y configurado"
    fi

    ping -c 1 -W 3 archlinux.org &>/dev/null || die "Sin conexión a Internet."
    ok "Conexión a Internet activa"
}

# ─── 2. Detección de GPU ──────────────────────────────────────────────────────

detect_gpu() {
    header "Detección de GPU"

    local vga_line
    vga_line=$(lspci | grep -Ei "VGA|3D|Display" | head -1)

    if echo "$vga_line" | grep -qi "intel"; then
        GPU_TYPE="intel"
        GPU_PKGS_OFFICIAL=("${PKGS_GPU_INTEL[@]}")
    elif echo "$vga_line" | grep -qi "amd\|ati"; then
        GPU_TYPE="amd"
        GPU_PKGS_OFFICIAL=("${PKGS_GPU_AMD[@]}")
    elif echo "$vga_line" | grep -qi "nvidia"; then
        GPU_TYPE="nvidia"
        GPU_PKGS_OFFICIAL=("${PKGS_GPU_NVIDIA[@]}")
    else
        GPU_TYPE="unknown"
        GPU_PKGS_OFFICIAL=()
        warn "GPU no reconocida: $vga_line"
        warn "Los drivers deberán instalarse manualmente después."
    fi

    ok "GPU detectada : $vga_line"
    ok "Tipo          : $GPU_TYPE"
    if [[ ${#GPU_PKGS_OFFICIAL[@]} -gt 0 ]]; then
        ok "Drivers       : ${GPU_PKGS_OFFICIAL[*]}"
    fi
}

select_file_manager() {
    header "Seleccionar Gestor de Archivos"
    echo "  1) Thunar (Ligero y rápido — recomendado para entornos livianos)"
    echo "  2) Nautilus (Moderno y estético — nativo de GNOME)"
    echo ""
    local fm_choice=""
    if [[ -e /dev/tty ]]; then
        read -p "Opción [1-2] (Por defecto 1): " fm_choice < /dev/tty || fm_choice="1"
    else
        fm_choice="1"
    fi
    if [[ "$fm_choice" == "2" ]]; then
        FILE_MANAGER="nautilus"
        PKGS_FILES=(
            nautilus nautilus-python gnome-disk-utility
            dosfstools exfatprogs gvfs-mtp gvfs-nfs gvfs-smb
        )
    else
        FILE_MANAGER="thunar"
        PKGS_FILES=(
            thunar thunar-archive-plugin thunar-volman file-roller
            gnome-disk-utility dosfstools exfatprogs gvfs-mtp gvfs-nfs gvfs-smb
        )
    fi
    ok "Gestor de archivos seleccionado: $FILE_MANAGER"
}

# ─── 3. Menú de componentes opcionales ───────────────────────────────────────

menu_optional() {
    header "Componentes opcionales"
    echo -e "   Responde s/N para cada categoría:\n"

    if confirm "Herramientas de desarrollo (neovim, VSCode, rust, docker, lazygit...)"; then
        INSTALL_DEV=true
    fi

    if confirm "Virtualización QEMU/VMM (qemu-full, virt-manager, swtpm)"; then
        INSTALL_QEMU=true
    fi

    if confirm "Suite ofimática (LibreOffice, Obsidian, Typora, Evince)"; then
        INSTALL_OFFICE=true
    fi

    if confirm "Impresión (CUPS, system-config-printer)"; then
        INSTALL_PRINT=true
    fi

    if confirm "Sincronización en la Nube (Dropbox, Megasync)"; then
        INSTALL_SYNC=true
    fi

    if confirm "Spotify (cliente de música, AUR)"; then
        INSTALL_SPOTIFY=true
    fi

    echo -e "\n${BOLD}   Navegadores a instalar:${NC}"

    confirm "Firefox (oficial)" && INSTALL_BROWSERS+=("firefox")
    confirm "Google Chrome (AUR)" && INSTALL_BROWSERS+=("google-chrome")
    confirm "Brave (AUR)" && INSTALL_BROWSERS+=("brave-bin")
    confirm "Opera (AUR)" && INSTALL_BROWSERS+=("opera")
    confirm "Microsoft Edge (AUR)" && INSTALL_BROWSERS+=("microsoft-edge-stable-bin")
}

# ─── 4. Resumen y confirmación ────────────────────────────────────────────────

show_summary() {
    header "Resumen de instalación"

    echo -e "   ${BOLD}GPU y drivers:${NC}"
    info "Tipo: $GPU_TYPE — paquetes: ${GPU_PKGS_OFFICIAL[*]:-ninguno}"

    echo -e "\n   ${BOLD}Paquetes base (siempre):${NC}"
    info "Hyprland + Wayland, barra, display manager, terminal"
    info "Herramientas de sistema, archivos, fuentes, temas"
    info "Captura, multimedia, comunicaciones, OCR, CLI"

    echo -e "\n   ${BOLD}Opcionales seleccionados:${NC}"
    $INSTALL_DEV   && info "✓ Desarrollo (neovim, VSCode, rust, docker...)"
    $INSTALL_QEMU  && info "✓ Virtualización QEMU/VMM"
    $INSTALL_OFFICE && info "✓ Ofimática (LibreOffice, Obsidian, Typora)"
    $INSTALL_PRINT && info "✓ Impresión (CUPS)"
    $INSTALL_SYNC  && info "✓ Sincronización en la Nube (Dropbox, Megasync)"
    [[ ${#INSTALL_BROWSERS[@]} -gt 0 ]] && info "✓ Navegadores: ${INSTALL_BROWSERS[*]}"
    [[ ${#INSTALL_BROWSERS[@]} -eq 0 ]] && info "  Sin navegadores adicionales"

    echo -e "\n   ${BOLD}Pasos del script:${NC}"
    info "1. Snapshot snapper pre-instalacion-hyprland"
    info "2. Actualización completa del sistema"
    info "3. Instalación de paquetes oficiales"
    info "4. Instalación de paquetes AUR"
    info "5. Configuración de servicios"
    [[ "$GPU_TYPE" != "unknown" ]] && info "6. Instalación de drivers GPU ($GPU_TYPE)"
    $INSTALL_QEMU && info "7. Configuración QEMU/libvirt"
    $INSTALL_DEV  && info "8. Configuración Docker"
    info "9. Plymouth (boot splash) — tema spinner, hook mkinitcpio, rebuild initramfs"

    echo ""
    confirm "¿Confirmas la instalación?" || die "Instalación cancelada por el usuario."
}

# ─── 5. Snapshot previo ───────────────────────────────────────────────────────

take_snapshot() {
    step "Creando snapshot pre-instalacion..."
    sudo snapper -c root create --description "pre-instalacion-hyprland"
    local snap_num
    snap_num=$(sudo snapper -c root list | tail -1 | awk '{print $1}')
    ok "Snapshot #${snap_num} creado: pre-instalacion-hyprland"
    ok "Rollback disponible desde GRUB → CachyOS Snapshots o Capítulo 11"
}

# ─── 6. AUR helper ───────────────────────────────────────────────────────────

setup_aur() {
    step "Verificando AUR helper..."

    if command -v paru &>/dev/null; then
        AUR_CMD="paru"
        ok "paru disponible"
        return
    fi

    warn "paru no encontrado — instalando desde repos CachyOS..."
    sudo pacman -S --needed --noconfirm paru \
        || die "Falló la instalación de paru. Verifica conexión y repos de CachyOS."
    command -v paru &>/dev/null || die "paru no se instaló correctamente."
    AUR_CMD="paru"
    ok "paru instalado"
}

# ─── 7. Actualización del sistema ─────────────────────────────────────────────

configure_mirrors() {
    step "Configurando mirrors (puede tardar ~1 minuto)..."
    if ! command -v cachyos-rate-mirrors &>/dev/null; then
        warn "cachyos-rate-mirrors no está disponible — se omite (mirrors actuales se mantienen)"
        return
    fi
    sudo cachyos-rate-mirrors \
        || warn "cachyos-rate-mirrors falló — continuando con mirrors actuales"
    ok "Mirrors configurados"
}

update_system() {
    step "Actualizando el sistema..."
    ensure_pacman_unlocked
    sudo pacman -Syu --noconfirm \
        || die "Falló la actualización del sistema — verifica mirrors y conexión"
    ok "Sistema actualizado"
}

# ─── 8. Instalación de paquetes oficiales ─────────────────────────────────────

install_official() {
    step "Instalando paquetes oficiales..."

    local pkgs=(
        "${PKGS_HYPRLAND[@]}"
        "${PKGS_BAR[@]}"
        "${PKGS_DM[@]}"
        "${PKGS_TERMINAL[@]}"
        "${PKGS_SYSTEM[@]}"
        "${PKGS_FILES[@]}"
        "${PKGS_FONTS[@]}"
        "${PKGS_THEMES[@]}"
        "${PKGS_CAPTURE[@]}"
        "${PKGS_MEDIA[@]}"
        "${PKGS_COMMS[@]}"
        "${PKGS_OCR[@]}"
        "${PKGS_CLI[@]}"
        "${GPU_PKGS_OFFICIAL[@]}"
    )

    $INSTALL_DEV   && pkgs+=("${PKGS_DEV_OFFICIAL[@]}")
    $INSTALL_QEMU  && pkgs+=("${PKGS_QEMU_OFFICIAL[@]}")
    $INSTALL_OFFICE && pkgs+=("${PKGS_OFFICE_OFFICIAL[@]}")
    $INSTALL_PRINT && pkgs+=("${PKGS_PRINT_OFFICIAL[@]}")

    for b in "${INSTALL_BROWSERS[@]}"; do
        pkgs+=("$b")
    done

    $AUR_CMD -S --needed --noconfirm "${pkgs[@]}"
    ok "Paquetes instalados"

    if [[ "$GPU_TYPE" == "intel" ]]; then
        step "Instalando sof-firmware (DSP Intel)..."
        $AUR_CMD -S --needed --noconfirm sof-firmware
        ok "sof-firmware instalado — reinicio requerido para activar audio Intel"
    fi
}

# ─── 9. Instalación de paquetes AUR ──────────────────────────────────────────

install_aur() {
    step "Instalando paquetes AUR..."

    local pkgs=("${PKGS_AUR_BASE[@]}")

    $INSTALL_DEV     && pkgs+=("${PKGS_DEV_AUR[@]}")
    $INSTALL_OFFICE  && pkgs+=("${PKGS_OFFICE_AUR[@]}")
    $INSTALL_SYNC    && pkgs+=("${PKGS_SYNC_AUR[@]}")
    $INSTALL_SPOTIFY && pkgs+=("spotify")

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        if ! $AUR_CMD -S --needed --noconfirm --skipreview "${pkgs[@]}"; then
            warn "Lote AUR tuvo fallos — reintentando paquete a paquete..."
            local failed_pkgs=()
            for pkg in "${pkgs[@]}"; do
                pacman -Qq "$pkg" &>/dev/null && continue
                $AUR_CMD -S --needed --noconfirm --skipreview "$pkg" \
                    || { warn "$pkg no se pudo instalar — continuando"; failed_pkgs+=("$pkg"); }
            done
            [[ ${#failed_pkgs[@]} -gt 0 ]] \
                && warn "Paquetes AUR no instalados: ${failed_pkgs[*]}" \
                || ok "Todos los paquetes AUR instalados en reintento individual"
        else
            ok "Paquetes AUR instalados"
        fi
    else
        info "No hay paquetes AUR adicionales seleccionados"
    fi

    # Paquetes críticos que otros pasos del script requieren — sin set -e,
    # los fallos individuales de paru pasan desapercibidos.
    local critical_aur_pkgs=(sddm-astronaut-theme)
    local failed_critical=()
    for pkg in "${critical_aur_pkgs[@]}"; do
        pacman -Qq "$pkg" &>/dev/null || failed_critical+=("$pkg")
    done
    if [[ ${#failed_critical[@]} -gt 0 ]]; then
        warn "Paquetes AUR críticos no instalados: ${failed_critical[*]}"
        warn "Reintentando instalación individual..."
        for pkg in "${failed_critical[@]}"; do
            $AUR_CMD -S --needed --noconfirm --skipreview "$pkg" \
                && ok "$pkg instalado en reintento" \
                || warn "$pkg falló — la configuración que lo requiere emitirá advertencia"
        done
    fi
}

# ─── 10. Configuración de servicios ──────────────────────────────────────────

configure_services() {
    header "Configurando servicios"

    step "Configurando SDDM + sddm-astronaut..."
    sudo mkdir -p /etc/sddm.conf.d
    sudo tee /etc/sddm.conf.d/hyprland.conf > /dev/null << 'SDDM_EOF'
[Theme]
Current=sddm-astronaut-theme
SDDM_EOF
    sudo systemctl enable sddm.service
    ok "SDDM habilitado — la pantalla de login aparecerá en el próximo arranque"
    info "Tema: sddm-astronaut-theme → /usr/share/sddm/themes/sddm-astronaut-theme/"
    info "Configuración en /etc/sddm.conf.d/hyprland.conf"

    local theme_src="/usr/share/sddm/themes/sddm-astronaut-theme/theme.conf"
    local theme_dst="/etc/sddm.conf.d/sddm-astronaut-theme.conf"
    if [[ -f "$theme_dst" ]]; then
        ok "sddm-astronaut-theme.conf ya existe en /etc/sddm.conf.d/"
    elif [[ -f "$theme_src" ]]; then
        sudo cp "$theme_src" "$theme_dst"
        ok "theme.conf copiado a $theme_dst — edítalo para personalizar el login screen"
    else
        warn "theme.conf no encontrado en $theme_src — omitiendo copia"
    fi

    step "Ocultando sesión Hyprland sin UWSM de SDDM..."
    # NoDisplay=true    # Asegurar que las sesiones de Hyprland estén visibles para SDDM y UWSM
    sudo sed -i '/NoDisplay=true/d' /usr/share/wayland-sessions/hyprland.desktop 2>/dev/null || true
    sudo rm -f /etc/pacman.d/hooks/hyprland-hide-plain-session.hook

    step "Habilitando servicios de audio..."
    systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service 2>/dev/null || true
    ok "PipeWire habilitado"

    step "Habilitando Bluetooth..."
    sudo systemctl enable --now bluetooth.service
    ok "bluetooth.service activo"

    step "Habilitando avahi-daemon + mDNS..."
    sudo systemctl enable --now avahi-daemon.service
    ok "avahi-daemon habilitado"
    if grep -q 'mdns_minimal' /etc/nsswitch.conf; then
        ok "nsswitch.conf ya tiene mdns_minimal"
    else
        sudo sed -i 's/^\(hosts:.*\)\bresolve\b/\1mdns_minimal [NOTFOUND=return] resolve/' /etc/nsswitch.conf
        ok "nsswitch.conf actualizado — resolución .local activa"
    fi

    step "Configurando firewall (ufw)..."
    if systemctl is-active --quiet ufw 2>/dev/null; then
        ok "ufw ya activo — omitiendo"
    else
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh comment 'SSH'
        sudo ufw allow 5353/udp comment 'mDNS avahi'
        sudo ufw allow in proto udp to any port 33434:33524 comment 'traceroute'
        sudo ufw --force enable
        sudo systemctl enable ufw
        ok "ufw activo — deny incoming, SSH, mDNS y traceroute permitidos"
    fi

    if $INSTALL_PRINT; then
        step "Habilitando CUPS..."
        sudo systemctl enable --now cups.service
        ok "CUPS habilitado"
    fi

    if $INSTALL_DEV; then
        step "Configurando Docker..."
        sudo systemctl enable --now docker.service
        sudo usermod -aG docker "$USER"
        ok "Docker habilitado — se requiere reiniciar para que el grupo surta efecto"

    fi

    if $INSTALL_QEMU; then
        step "Configurando QEMU/libvirt..."
        grep -q 'firewall_backend = "iptables"' /etc/libvirt/network.conf 2>/dev/null || \
            echo 'firewall_backend = "iptables"' | sudo tee -a /etc/libvirt/network.conf > /dev/null
        sudo usermod -aG libvirt "$USER"
        sudo systemctl enable --now libvirtd.socket
        sudo virsh net-autostart default 2>/dev/null || true
        ok "QEMU/libvirt configurado"
        warn "Se requiere reiniciar para que el grupo libvirt surta efecto"
    fi

    configure_plymouth
    configure_grub
    install_sddm_bg_switcher
}

# ─── 10b. SDDM Background Switcher ───────────────────────────────────────────

install_sddm_bg_switcher() {
    local theme_dir="/usr/share/sddm/themes/sddm-astronaut-theme"
    local bg_dir="$theme_dir/Backgrounds"
    local theme_conf="/etc/sddm.conf.d/sddm-astronaut-theme.conf"

    if [[ ! -d "$bg_dir" ]]; then
        warn "sddm-astronaut-theme no encontrado en $bg_dir — omitiendo bg-switcher"
        return
    fi

    step "Configurando SDDM Background Switcher..."

    # Helper con privilegios (sudoers apunta a este binario específico)
    sudo tee /usr/local/bin/sddm-apply-bg > /dev/null << 'HELPER_EOF'
#!/bin/bash
bg="$1"
conf="/etc/sddm.conf.d/sddm-astronaut-theme.conf"
[[ -f "$conf" ]] || { echo "ERROR: $conf no existe"; exit 1; }
[[ -n "$bg" ]]   || { echo "ERROR: nombre de fondo vacío"; exit 1; }
if grep -q '^Background=' "$conf"; then
    sed -i "s|^Background=.*|Background=Backgrounds/$bg|" "$conf"
else
    sed -i '/^\[General\]/a Background=Backgrounds/'"$bg" "$conf"
fi
echo "LISTO — fondo aplicado: $bg"
HELPER_EOF
    sudo chmod 755 /usr/local/bin/sddm-apply-bg
    ok "Helper /usr/local/bin/sddm-apply-bg creado"

    # Regla sudoers — NOPASSWD solo para ese binario
    echo "$USER ALL=(root) NOPASSWD: /usr/local/bin/sddm-apply-bg" \
        | sudo tee /etc/sudoers.d/sddm-bg-switcher > /dev/null
    sudo chmod 440 /etc/sudoers.d/sddm-bg-switcher
    ok "Sudoers: NOPASSWD para sddm-apply-bg"

    # Script de usuario
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/sddm-bg-switcher" << SWITCHER_EOF
#!/bin/bash
BG_DIR="/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds"
THEME="\$HOME/.config/omarchy/current/rofi.rasi"
ROFI_ARGS=(-dmenu -p "Fondo SDDM" -i -no-custom)
[[ -f "\$THEME" ]] && ROFI_ARGS+=(-theme "\$THEME")

selected=\$(ls "\$BG_DIR" | rofi "\${ROFI_ARGS[@]}")
[[ -z "\$selected" ]] && exit 0

sudo /usr/local/bin/sddm-apply-bg "\$selected" \
    && notify-send "SDDM Background" "Fondo aplicado: \$selected" \
    || notify-send -u critical "SDDM Background" "Error al aplicar: \$selected"
SWITCHER_EOF
    chmod +x "$HOME/.local/bin/sddm-bg-switcher"
    ok "Script ~/.local/bin/sddm-bg-switcher creado"

    # Entrada .desktop para rofi
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/sddm-bg-switcher.desktop" << EOF
[Desktop Entry]
Name=SDDM Background Switcher
Comment=Cambiar fondo de pantalla del login screen
Exec=$HOME/.local/bin/sddm-bg-switcher
Icon=preferences-desktop-wallpaper
Terminal=false
Type=Application
Categories=System;Settings;
Keywords=sddm;login;background;wallpaper;
NoDisplay=false
EOF
    ok "Entrada SDDM Background Switcher disponible en rofi"
}

# ─── 10d. GRUB ───────────────────────────────────────────────────────────────

configure_grub() {
    [[ -f /etc/default/grub ]] || { info "GRUB no detectado — omitiendo configuración de GRUB"; return; }

    step "Instalando colección de temas GRUB (10 temas)..."

    local themes_sys="/usr/share/grub/themes"
    local tmp; tmp=$(mktemp -d)

    # ── Catppuccin (×4 sabores) ───────────────────────────────────────────
    local _cat_cloned=0
    for _flavor in mocha latte frappe macchiato; do
        local _td="${themes_sys}/catppuccin-${_flavor}-grub-theme"
        if [[ -d "$_td" ]]; then
            ok "catppuccin-${_flavor}: ya instalado"
        else
            if [[ "$_cat_cloned" -eq 0 ]]; then
                git clone --depth 1 https://github.com/catppuccin/grub.git "$tmp/catppuccin" 2>/dev/null \
                    && _cat_cloned=1 \
                    || { warn "No se pudo clonar catppuccin/grub"; break; }
            fi
            sudo cp -r "$tmp/catppuccin/src/catppuccin-${_flavor}-grub-theme" "$themes_sys/"
            ok "catppuccin-${_flavor} instalado"
        fi
    done

    # ── Gruvbox ───────────────────────────────────────────────────────────
    if [[ -d "${themes_sys}/gruvbox" ]]; then
        ok "gruvbox: ya instalado"
    elif git clone --depth 1 https://github.com/x4121/grub-gruvbox.git "$tmp/gruvbox" 2>/dev/null; then
        sudo cp -r "$tmp/gruvbox" "${themes_sys}/gruvbox"
        ok "gruvbox instalado"
    else
        warn "No se pudo instalar gruvbox"
    fi

    # ── Dracula ───────────────────────────────────────────────────────────
    if [[ -d "${themes_sys}/dracula" ]]; then
        ok "dracula: ya instalado"
    elif git clone --depth 1 https://github.com/dracula/grub.git "$tmp/dracula-repo" 2>/dev/null; then
        sudo cp -r "$tmp/dracula-repo" "${themes_sys}/dracula"
        ok "dracula instalado"
    else
        warn "No se pudo instalar dracula"
    fi

    # ── Nord ──────────────────────────────────────────────────────────────
    if [[ -d "${themes_sys}/nord" ]]; then
        ok "nord: ya instalado"
    elif git clone --depth 1 https://github.com/jlempen/grub2-theme-arch-nord.git "$tmp/nord-repo" 2>/dev/null; then
        sudo cp -r "$tmp/nord-repo" "${themes_sys}/nord"
        ok "nord instalado"
    else
        warn "No se pudo instalar nord"
    fi

    # ── Tela y Stylish (vinceliuice) ──────────────────────────────────────
    # vinceliuice instala en /boot/grub/themes/ → se copia a /usr/share/grub/themes/
    local _vince_cloned=0
    for _t in tela stylish; do
        if [[ -d "${themes_sys}/${_t}" ]]; then
            ok "${_t}: ya instalado"
        else
            if [[ "$_vince_cloned" -eq 0 ]]; then
                git clone --depth 1 https://github.com/vinceliuice/grub2-themes.git "$tmp/vince" 2>/dev/null \
                    && _vince_cloned=1 \
                    || { warn "No se pudo clonar vinceliuice/grub2-themes"; break; }
            fi
            (cd "$tmp/vince" && sudo bash install.sh -t "$_t" -b -s 1080p 2>/dev/null) || true
            [[ -d "/boot/grub/themes/${_t}" ]] && sudo cp -r "/boot/grub/themes/${_t}" "${themes_sys}/"
            [[ -d "${themes_sys}/${_t}" ]] && ok "${_t} instalado" || warn "No se pudo instalar ${_t}"
        fi
    done

    rm -rf "$tmp"

    # ── Tema activo por defecto (catppuccin-mocha) ────────────────────────
    local grub_theme="${themes_sys}/catppuccin-mocha-grub-theme/theme.txt"
    if [[ -f "$grub_theme" ]]; then
        if grep -q "^GRUB_THEME=\"$grub_theme\"" /etc/default/grub; then
            ok "GRUB_THEME ya configurado"
        else
            sudo sed -i 's|^#\?GRUB_THEME=.*||' /etc/default/grub
            echo "GRUB_THEME=\"$grub_theme\"" | sudo tee -a /etc/default/grub > /dev/null
            ok "GRUB_THEME=catppuccin-mocha-grub-theme configurado"
        fi
    else
        warn "GRUB_THEME omitido — el menú quedará en gfxterm sin tema"
    fi

    sudo grub-mkconfig -o /boot/grub/grub.cfg
    ok "grub.cfg regenerado — menú gráfico con tema activo al próximo arranque"

    # ── GRUB Theme Switcher para rofi ─────────────────────────────────────────
    step "Configurando GRUB Theme Switcher..."

    # Helper con privilegios (sudoers apunta a este binario específico)
    sudo tee /usr/local/bin/grub-apply-theme > /dev/null << 'HELPER_EOF'
#!/bin/bash
theme="$1"
[[ -f "$theme" ]] || { echo "ERROR: theme.txt no encontrado: $theme"; exit 1; }
sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$theme\"|" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg \
    && echo "LISTO — tema aplicado: $(basename "$(dirname "$theme")")"
HELPER_EOF
    sudo chmod 755 /usr/local/bin/grub-apply-theme
    ok "Helper /usr/local/bin/grub-apply-theme creado"

    # Regla sudoers — NOPASSWD solo para ese binario
    echo "$USER ALL=(root) NOPASSWD: /usr/local/bin/grub-apply-theme" \
        | sudo tee /etc/sudoers.d/grub-theme-switcher > /dev/null
    sudo chmod 440 /etc/sudoers.d/grub-theme-switcher
    ok "Sudoers: NOPASSWD para grub-apply-theme"

    # Script de usuario
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/grub-theme-switcher" << 'SWITCHER_EOF'
#!/bin/bash
THEMES_DIR="/usr/share/grub/themes"
selected=$(ls "$THEMES_DIR" | rofi -dmenu -p "Tema GRUB" -i)
[[ -z "$selected" ]] && exit 0
theme="$THEMES_DIR/$selected/theme.txt"
if [[ ! -f "$theme" ]]; then
    notify-send "GRUB Theme Switcher" "theme.txt no encontrado en: $selected"
    exit 1
fi
sudo /usr/local/bin/grub-apply-theme "$theme"
echo ""
echo "Presiona Enter para cerrar..."
read -r _
SWITCHER_EOF
    chmod +x "$HOME/.local/bin/grub-theme-switcher"
    ok "Script ~/.local/bin/grub-theme-switcher creado"

    # Entrada .desktop para rofi
    mkdir -p "$HOME/.local/share/applications"
    cat > "$HOME/.local/share/applications/grub-theme-switcher.desktop" << EOF
[Desktop Entry]
Name=GRUB Theme Switcher
Comment=Cambiar tema visual del menú GRUB
Exec=alacritty -e $HOME/.local/bin/grub-theme-switcher
Icon=preferences-system-details
Terminal=false
Type=Application
Categories=System;Settings;
Keywords=grub;theme;boot;
NoDisplay=false
EOF
    ok "Entrada GRUB Theme Switcher disponible en rofi"

    # ── Mapeo omarchy → GRUB theme ────────────────────────────────────────────
    local grub_map="${HOME}/.local/share/omarchy-local/grub-theme-map"
    mkdir -p "$(dirname "$grub_map")"
    if [[ -f "$grub_map" ]]; then
        ok "grub-theme-map ya existe"
    else
        cat > "$grub_map" << 'MAP_EOF'
default=catppuccin-mocha-grub-theme
catppuccin=catppuccin-mocha-grub-theme
catppuccin-latte=catppuccin-latte-grub-theme
ethereal=catppuccin-macchiato-grub-theme
everforest=gruvbox
flexoki-light=catppuccin-latte-grub-theme
gruvbox=gruvbox
hackerman=stylish
kanagawa=catppuccin-mocha-grub-theme
last-horizon=tela
lumon=catppuccin-latte-grub-theme
matte-black=stylish
miasma=catppuccin-mocha-grub-theme
nord=nord
osaka-jade=catppuccin-macchiato-grub-theme
retro-82=dracula
ristretto=catppuccin-frappe-grub-theme
rose-pine=dracula
solitude=catppuccin-latte-grub-theme
tokyo-night=catppuccin-mocha-grub-theme
vantablack=stylish
white=catppuccin-latte-grub-theme
MAP_EOF
        ok "grub-theme-map creado (mapeo de 21 temas omarchy → GRUB)"
    fi
}

# ─── 10e. Plymouth (boot splash) ─────────────────────────────────────────────

configure_plymouth() {
    step "Configurando Plymouth (boot splash)..."

    # Hook en mkinitcpio — debe ir después de 'udev'
    if grep -q 'HOOKS.*plymouth' /etc/mkinitcpio.conf 2>/dev/null; then
        ok "Hook 'plymouth' ya presente en mkinitcpio.conf"
    else
        sudo sed -i 's/\(HOOKS=([^)]*udev\)/\1 plymouth/' /etc/mkinitcpio.conf
        ok "Hook 'plymouth' añadido después de 'udev' en mkinitcpio.conf"
    fi

    # Parámetro splash en el cmdline del kernel
    if [[ -f /etc/kernel/cmdline ]]; then
        if grep -q 'splash' /etc/kernel/cmdline; then
            ok "Parámetro 'quiet splash' ya presente en /etc/kernel/cmdline"
        else
            sudo sed -i 's/$/ quiet splash/' /etc/kernel/cmdline
            ok "Añadido 'quiet splash' a /etc/kernel/cmdline"
        fi
    elif [[ -f /etc/default/grub ]]; then
        if grep -q 'splash' /etc/default/grub; then
            ok "Parámetro 'quiet splash' ya presente en GRUB_CMDLINE_LINUX_DEFAULT"
        else
            sudo sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 quiet splash"/' /etc/default/grub
            ok "Añadido 'quiet splash' a GRUB_CMDLINE_LINUX_DEFAULT"
        fi
    else
        warn "Bootloader no detectado — añade 'quiet splash' al cmdline manualmente"
    fi

    # Tema Omarchy — archivos estáticos del repo basecamp/omarchy (no está en repos).
    # omarchy.plymouth usa rutas absolutas /usr/share/plymouth/themes/omarchy.
    local omarchy_dir="/usr/share/plymouth/themes/omarchy"
    if [[ -f "$omarchy_dir/omarchy.plymouth" ]]; then
        ok "Tema Plymouth Omarchy ya instalado"
    else
        step "Instalando tema Plymouth Omarchy..."
        local tmp; tmp=$(mktemp -d)
        if git clone --depth 1 https://github.com/basecamp/omarchy.git "$tmp" 2>/dev/null; then
            sudo mkdir -p "$omarchy_dir"
            sudo cp -r "$tmp/default/plymouth/." "$omarchy_dir/"
            ok "Tema Omarchy instalado en $omarchy_dir"
        else
            warn "No se pudo clonar basecamp/omarchy — se usará el tema cachyos"
        fi
        rm -rf "$tmp"
    fi

    # Tema y rebuild de initramfs
    if [[ -f "$omarchy_dir/omarchy.plymouth" ]]; then
        sudo plymouth-set-default-theme -R omarchy
        ok "Plymouth configurado — tema: omarchy"
    else
        sudo plymouth-set-default-theme -R cachyos
        ok "Plymouth configurado — tema: cachyos (fallback)"
    fi
    info "Para cambiar el tema: sudo plymouth-set-default-theme -R <tema>"
    info "Temas disponibles: sudo plymouth-set-default-theme --list"
}

# ─── 11. Resumen final ────────────────────────────────────────────────────────

final_summary() {
    header "Instalación completada"

    echo -e "   ${BOLD}Estado:${NC}"
    ok "Hyprland instalado"
    ok "GPU ($GPU_TYPE) con drivers: ${GPU_PKGS_OFFICIAL[*]:-manual}"
    ok "SDDM habilitado — pantalla de login al próximo reinicio"
    ok "Snapshot de rollback disponible en GRUB → CachyOS Snapshots"

    echo -e "\n   ${BOLD}Grupos nuevos asignados al usuario $USER:${NC}"
    $INSTALL_DEV  && info "docker  (efectivo tras reinicio)"
    $INSTALL_QEMU && info "libvirt (efectivo tras reinicio)"

    echo -e "\n   ${BOLD}Próximo paso:${NC}"
    info "Reinicia el sistema para arrancar en Hyprland:"
    echo -e "\n   ${BOLD}sudo reboot${NC}\n"

    echo -e "   ${DIM}Si algo falla, consulta el Capítulo 11 para el procedimiento de rollback.${NC}"
    echo -e "   ${DIM}El snapshot 'pre-instalacion-hyprland' está disponible en GRUB.${NC}\n"
}

# ─── Main ─────────────────────────────────────────────────────────────────────

header "Instalador Hyprland para CachyOS"
echo -e "   ${DIM}Inspirado en Omarchy (DHH) y omarchy-on-cachyos (mroboff)${NC}"

check_prereqs
detect_gpu
select_file_manager
menu_optional
show_summary
take_snapshot
configure_mirrors
update_system
setup_aur
install_official
install_aur
configure_services
sudo snapper -c root create --description "post-instalacion-hyprland"
ok "Snapshot post-instalacion-hyprland creado"
final_summary
