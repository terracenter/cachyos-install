#!/bin/bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ install-gaming.sh                                                           │
# │ Gaming en CachyOS: Steam nativo + Proton-GE + GameMode + MangoHud          │
# │                                                                             │
# │ Sin Flatpak. Sin Snap. Sin AppImage.                                        │
# │ Habilita multilib SOLO para los paquetes necesarios de gaming.              │
# │ Requiere install-hyprland-desktop.sh ejecutado previamente.                │
# └─────────────────────────────────────────────────────────────────────────────┘

set -uo pipefail

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

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

# ─── Opcionales ───────────────────────────────────────────────────────────────
INSTALL_PROTONUP=false
INSTALL_LUTRIS=false
INSTALL_WINE=false

# ─── Detección de GPU ─────────────────────────────────────────────────────────
detect_gpu() {
    local result=""
    lspci | grep -Ei "VGA|3D|Display" | grep -qi nvidia && result="$result nvidia"
    lspci | grep -Ei "VGA|3D|Display" | grep -qi amd   && result="$result amd"
    lspci | grep -Ei "VGA|3D|Display" | grep -qi intel && result="$result intel"
    echo "${result# }"
}

pacman_install() {
    local pkgs=("$@")
    if ! sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
        warn "Lote pacman tuvo fallos — reintentando paquete a paquete..."
        local failed=()
        for pkg in "${pkgs[@]}"; do
            pacman -Qq "$pkg" &>/dev/null && continue
            sudo pacman -S --needed --noconfirm "$pkg" \
                || { warn "$pkg no se pudo instalar — continuando"; failed+=("$pkg"); }
        done
        [[ ${#failed[@]} -gt 0 ]] && warn "Paquetes no instalados: ${failed[*]}"
    fi
}

aur_install() {
    local pkgs=("$@")
    if ! paru -S --needed --noconfirm --skipreview "${pkgs[@]}"; then
        warn "Lote AUR tuvo fallos — reintentando paquete a paquete..."
        local failed=()
        for pkg in "${pkgs[@]}"; do
            pacman -Qq "$pkg" &>/dev/null && continue
            paru -S --needed --noconfirm --skipreview "$pkg" \
                || { warn "$pkg no se pudo instalar — continuando"; failed+=("$pkg"); }
        done
        [[ ${#failed[@]} -gt 0 ]] && warn "Paquetes AUR no instalados: ${failed[*]}"
    fi
}

configure_mirrors() {
    step "Configurando mirrors (puede tardar ~1 minuto)..."
    sudo cachyos-rate-mirrors \
        || die "cachyos-rate-mirrors falló — verifica conexión a Internet"
    ok "Mirrors configurados"
}

update_system() {
    step "Actualizando el sistema..."
    sudo pacman -Syu --noconfirm \
        || die "Falló la actualización del sistema — verifica mirrors y conexión"
    ok "Sistema actualizado"
}

# ─── Prerequisitos ────────────────────────────────────────────────────────────
check_prereqs() {
    header "Verificando prerequisitos"

    [[ $EUID -ne 0 ]] || die "No ejecutes el script como root. Usa tu usuario normal."
    ok "Usuario normal: $(whoami)"

    sudo -v 2>/dev/null || die "Este usuario no tiene privilegios sudo."
    ok "Privilegios sudo disponibles"

    command -v paru &>/dev/null || die "paru no instalado. Ejecuta install-cachyos-hyprland.sh primero."
    ok "paru disponible"

    ping -c 1 -W 3 archlinux.org &>/dev/null || die "Sin conexión a Internet."
    ok "Conexión a Internet activa"

    local gpus
    gpus=$(detect_gpu)
    ok "GPU detectada: ${gpus:-desconocida}"
}

# ─── Menú de opcionales ───────────────────────────────────────────────────────
menu_optional() {
    header "Componentes opcionales"

    echo -e "
   ${BOLD}¿Qué instala cada herramienta?${NC}

   ┌──────────────────┬────────────────────────────────────────────────────┐
   │ Herramienta      │ Para qué sirve                                     │
   ├──────────────────┼────────────────────────────────────────────────────┤
   │ ProtonUp-Qt      │ Instala y actualiza Proton-GE dentro de Steam.     │
   │ ${GREEN}[RECOMENDADO]${NC}    │ Proton-GE tiene más compatibilidad que el Proton   │
   │                  │ oficial. Una sola función, sin configuración.      │
   ├──────────────────┼────────────────────────────────────────────────────┤
   │ Lutris           │ Gestiona juegos de Epic Games, GOG, itch.io y      │
   │ ${GREEN}[RECOMENDADO si${NC}  │ emuladores desde un solo panel. Descarga sus       │
   │ ${GREEN}tienes Epic/GOG]${NC} │ propios runners de Wine/Proton. App nativa Python. │
   ├──────────────────┼────────────────────────────────────────────────────┤
   │ Wine Staging     │ Para ejecutar .exe de Windows directamente, sin    │
   │ ${DIM}[avanzado]${NC}        │ Steam ni Lutris. Útil para juegos viejos (Delta    │
   │                  │ Force 1999, simuladores legacy sin plataforma).    │
   └──────────────────┴────────────────────────────────────────────────────┘

   ${DIM}Los tres pueden coexistir sin conflicto.${NC}
   ${DIM}Para empezar: ProtonUp-Qt (siempre) + Lutris (si tienes Epic o GOG).${NC}
"

    confirm "ProtonUp-Qt — gestión de Proton-GE para Steam [RECOMENDADO]"          && INSTALL_PROTONUP=true
    confirm "Lutris — Epic Games, GOG y otras plataformas [si tienes esas cuentas]" && INSTALL_LUTRIS=true
    confirm "Wine Staging — ejecutar .exe directamente [avanzado]"                  && INSTALL_WINE=true
}

# ─── Multilib ─────────────────────────────────────────────────────────────────
enable_multilib() {
    header "Repositorio multilib"

    if grep -q '^\[multilib\]' /etc/pacman.conf; then
        ok "multilib ya habilitado"
        return
    fi

    info "Habilitando [multilib] en /etc/pacman.conf..."
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    sudo pacman -Sy --noconfirm
    ok "multilib habilitado y base de datos sincronizada"
}

# ─── lib32 para gaming ────────────────────────────────────────────────────────
install_lib32() {
    header "lib32 para gaming"

    local gpus
    gpus=$(detect_gpu)

    # Base: necesarios para Wine/Proton independientemente de la GPU
    local pkgs=(lib32-glibc lib32-gcc-libs lib32-vulkan-icd-loader lib32-gamemode lib32-mangohud)

    if echo "$gpus" | grep -q nvidia; then
        pkgs+=(lib32-nvidia-utils lib32-opencl-nvidia)
        info "NVIDIA detectada → lib32-nvidia-utils lib32-opencl-nvidia"
    fi
    if echo "$gpus" | grep -qE "amd|intel"; then
        pkgs+=(lib32-mesa)
        info "AMD/Intel detectada → lib32-mesa"
    fi
    if echo "$gpus" | grep -q amd; then
        pkgs+=(lib32-vulkan-radeon)
        info "AMD → lib32-vulkan-radeon"
    fi
    if echo "$gpus" | grep -q intel; then
        pkgs+=(lib32-vulkan-intel)
        info "Intel → lib32-vulkan-intel"
    fi
    [[ -z "$gpus" ]] && pkgs+=(lib32-mesa) && warn "GPU no detectada — lib32-mesa genérico"

    info "${#pkgs[@]} paquetes lib32 en total — solo esto toca el sistema base"

    pacman_install "${pkgs[@]}"
    ok "lib32 gaming instalado"
}

# ─── Steam ────────────────────────────────────────────────────────────────────
install_steam() {
    header "Steam (nativo)"

    if pacman -Q steam &>/dev/null; then
        ok "steam ya instalado"
    else
        pacman_install steam
        ok "steam instalado"
    fi
}

# ─── GameMode ─────────────────────────────────────────────────────────────────
install_gamemode() {
    header "GameMode"

    if pacman -Q gamemode &>/dev/null; then
        ok "gamemode ya instalado"
    else
        aur_install gamemode
        ok "gamemode instalado"
    fi

    if groups "$(whoami)" | grep -qw gamemode; then
        ok "Usuario ya en grupo gamemode"
    else
        sudo usermod -aG gamemode "$(whoami)"
        ok "Usuario añadido al grupo gamemode (efecto en el próximo login)"
    fi

    if gamemoded -t &>/dev/null; then
        ok "gamemode operativo"
    else
        warn "gamemode: verifica con 'gamemoded -t' tras reiniciar sesión"
    fi
}

# ─── MangoHud ─────────────────────────────────────────────────────────────────
install_mangohud() {
    header "MangoHud"

    if pacman -Q mangohud &>/dev/null; then
        ok "mangohud ya instalado"
    else
        aur_install mangohud
        ok "mangohud instalado"
    fi

    local cfg="$HOME/.config/MangoHud/MangoHud.conf"
    if [[ -f "$cfg" ]]; then
        ok "MangoHud.conf ya existe"
    else
        mkdir -p "$(dirname "$cfg")"
        cat > "$cfg" << 'MANGOCFG'
fps
gpu_stats
gpu_temp
gpu_name
cpu_stats
cpu_temp
ram
vram
frame_timing=0
position=top-left
font_size=20
background_alpha=0.5
MANGOCFG
        ok "MangoHud.conf creado en ~/.config/MangoHud/"
    fi
}

# ─── ProtonUp-Qt ──────────────────────────────────────────────────────────────
install_protonup() {
    header "ProtonUp-Qt"

    if pacman -Q protonup-qt &>/dev/null; then
        ok "protonup-qt ya instalado"
    else
        aur_install protonup-qt
        ok "protonup-qt instalado"
    fi

    info "Abre ProtonUp-Qt → Add version → Steam → GE-Proton → instala la última versión"
}

# ─── Lutris ───────────────────────────────────────────────────────────────────
install_lutris() {
    header "Lutris"

    if pacman -Q lutris &>/dev/null; then
        ok "lutris ya instalado"
    else
        aur_install lutris
        ok "lutris instalado"
    fi
}

# ─── Wine Staging ─────────────────────────────────────────────────────────────
install_wine() {
    header "Wine Staging"

    if pacman -Q wine-staging &>/dev/null; then
        ok "wine-staging ya instalado"
    else
        pacman_install wine-staging winetricks
        ok "wine-staging + winetricks instalados"
    fi

    info "Para juegos .exe directos: wine /ruta/al/juego.exe"
    info "Para Delta Force 1999 y similares — configurar prefijo con winetricks"
}

# ─── Entradas en rofi ─────────────────────────────────────────────────────────
create_desktop_entries() {
    header "Entradas en el lanzador"

    local apps_dir="$HOME/.local/share/applications"
    mkdir -p "$apps_dir"

    # Wrapper que previene doble instancia de Steam en Hyprland
    sudo tee /usr/local/bin/steam-launch > /dev/null << 'WRAPPER'
#!/bin/bash
if hyprctl clients -j 2>/dev/null | grep -q '"class": "steam"'; then
    hyprctl dispatch focuswindow class:steam
else
    exec /usr/bin/steam "$@"
fi
WRAPPER
    sudo chmod +x /usr/local/bin/steam-launch
    ok "steam-launch wrapper instalado en /usr/local/bin/"

    # .desktop de usuario: sobreescribe el del sistema y usa el wrapper
    cat > "$apps_dir/steam.desktop" << 'EOF'
[Desktop Entry]
Name=Steam
Comment=Plataforma de juegos Steam
Exec=steam-launch %U
Icon=steam
Terminal=false
Type=Application
Categories=Game;
MimeType=x-scheme-handler/steam;x-scheme-handler/steamlink;
StartupWMClass=steam
EOF
    ok "steam.desktop (con wrapper) disponible en rofi"

    $INSTALL_PROTONUP && {
        cat > "$apps_dir/protonup-qt.desktop" << 'EOF'
[Desktop Entry]
Name=ProtonUp-Qt
Comment=Gestión de versiones de Proton-GE para Steam
Exec=protonup-qt
Icon=protonup-qt
Type=Application
Categories=Game;
NoDisplay=false
EOF
        ok "protonup-qt.desktop creado"
    }

    $INSTALL_LUTRIS && {
        if [[ -f /usr/share/applications/net.lutris.Lutris.desktop ]]; then
            cp /usr/share/applications/net.lutris.Lutris.desktop "$apps_dir/"
            ok "lutris.desktop disponible en rofi"
        fi
    }
}

# ─── Resumen final ────────────────────────────────────────────────────────────
final_summary() {
    header "Gaming listo"

    local lib32_count
    lib32_count=$(pacman -Q | grep -c '^lib32-')

    echo -e "\n   ${BOLD}Instalado:${NC}"
    ok "multilib habilitado — ${lib32_count} paquetes lib32 en el sistema"
    ok "Steam — cliente nativo con Proton integrado"
    ok "GameMode — optimización automática de CPU/GPU al jugar"
    ok "MangoHud — overlay de FPS, temperatura y uso de recursos"
    $INSTALL_PROTONUP && ok "ProtonUp-Qt — gestor de Proton-GE"
    $INSTALL_LUTRIS   && ok "Lutris — Epic Games, GOG y otras plataformas"
    $INSTALL_WINE     && ok "Wine Staging + winetricks"

    echo -e "\n   ${BOLD}lib32 instalados en el sistema:${NC}"
    pacman -Q | grep '^lib32-' | awk '{printf "      %s\n", $1}' | sort

    echo -e "\n   ${BOLD}Próximos pasos:${NC}"
    info "1. Cierra sesión y vuelve a entrar (grupo 'gamemode' surte efecto)"
    info "2. Abre Steam, inicia sesión, deja que actualice"
    info "3. Steam → Configuración → Compatibilidad → activar Proton para todos los juegos"
    $INSTALL_PROTONUP && info "4. ProtonUp-Qt → Add version → GE-Proton → instala la última"
    info "5. En cada juego → Propiedades → Opciones de lanzamiento:"
    echo -e "\n   ${CYAN}   MANGOHUD=1 gamemoderun %command%${NC}\n"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    header "Gaming en CachyOS — nativo, sin Flatpak, sin AppImage"
    check_prereqs
    configure_mirrors
    update_system
    menu_optional
    enable_multilib
    install_lib32
    install_steam
    install_gamemode
    install_mangohud
    $INSTALL_PROTONUP && install_protonup
    $INSTALL_LUTRIS   && install_lutris
    $INSTALL_WINE     && install_wine
    create_desktop_entries
    final_summary
}

main "$@"
