#!/bin/bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ install-qtile-omarchy.sh                                                    │
# │ Instalador del entorno Qtile-Omarchy (X11) para CachyOS                     │
# │ Portabilidad completa del sistema Omarchy (Temas, Applets, Scripts)         │
# └─────────────────────────────────────────────────────────────────────────────┘

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/configs"
LOG_FILE="$SCRIPT_DIR/install-qtile-omarchy.log"

source "$SCRIPT_DIR/../lib/common.sh"

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
step()  { echo -e "\n${BOLD}▶  $1${NC}"; }
ok()    { echo -e "   ${GREEN}✓  $1${NC}"; }
warn()  { echo -e "   ${YELLOW}⚠  $1${NC}"; }
info()  { echo -e "   ${DIM}→  $1${NC}"; }
die()   { echo -e "\n   ${RED}✗  $1${NC}\n" >&2; exit 1; }

# Verificar que NO es root
[[ $EUID -eq 0 ]] && die "No ejecutes el script como root. Usa tu usuario normal."

# Detección de hardware
is_laptop() {
    local chassis
    chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)
    case "$chassis" in
        8|9|10|11|14|31|32) return 0 ;;
    esac
    ls /sys/class/power_supply/BAT* &>/dev/null
}

AUR_CMD=""

# ─── AUR Helper Setup ─────────────────────────────────────────────────────────
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

paru_install() {
    local warn_mode=0
    if [[ "${1:-}" == "--warn" ]]; then
        warn_mode=1
        shift
    fi

    local pkgs=("$@")
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if pacman -Q "$pkg" &>/dev/null; then
            ok "$pkg ya instalado"
        else
            to_install+=("$pkg")
        fi
    done
    [[ ${#to_install[@]} -eq 0 ]] && return 0

    if ! $AUR_CMD -S --needed --noconfirm --skipreview "${to_install[@]}"; then
        warn "Lote AUR tuvo fallos — reintentando paquete a paquete..."
        local failed_pkgs=()
        for pkg in "${to_install[@]}"; do
            pacman -Qq "$pkg" &>/dev/null && continue
            $AUR_CMD -S --needed --noconfirm --skipreview "$pkg" \
                || { warn "$pkg no se pudo instalar — continuando"; failed_pkgs+=("$pkg"); }
        done
        if [[ ${#failed_pkgs[@]} -gt 0 ]]; then
            if [[ $warn_mode -eq 1 ]]; then
                warn "Paquetes AUR no instalados (no-críticos): ${failed_pkgs[*]}"
            else
                die "Paquetes críticos no se pudieron instalar: ${failed_pkgs[*]}"
            fi
        fi
    fi
}

pacman_install() {
    local pkgs=("$@")
    sudo pacman -S --needed --noconfirm "${pkgs[@]}" || warn "Error instalando ${pkgs[*]}"
}

confirm() {
    printf "\n${CYAN}   %s [s/N]: ${NC}" "$1"
    read -r _resp
    [[ "$_resp" =~ ^[sS]$ ]]
}

FILE_MANAGER=""
PKGS_FILES=()
INSTALL_BROWSERS=()
INSTALL_DEV=false
INSTALL_QEMU=false
INSTALL_OFFICE=false
INSTALL_PRINT=false
INSTALL_SYNC=false
INSTALL_SPOTIFY=false

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

select_file_manager() {
    header "Seleccionar Gestor de Archivos"
    echo "  1) Thunar (Ligero y rápido — recomendado para entornos livianos)"
    echo "  2) Nautilus (Moderno y estético — nativo de GNOME)"
    echo ""
    read -p "Opción [1-2] (Por defecto 1): " fm_choice < /dev/tty
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

show_summary() {
    header "Resumen de instalación"

    echo -e "   ${BOLD}Gestor de archivos:${NC}"
    info "Seleccionado: $FILE_MANAGER"

    echo -e "\n   ${BOLD}Paquetes base (siempre):${NC}"
    info "Qtile (X11), picom, terminal Alacritty, herramientas de sistema"

    echo -e "\n   ${BOLD}Opcionales seleccionados:${NC}"
    $INSTALL_DEV   && info "✓ Desarrollo (neovim, VSCode, rust, docker...)"
    $INSTALL_QEMU  && info "✓ Virtualización QEMU/VMM"
    $INSTALL_OFFICE && info "✓ Ofimática (LibreOffice, Obsidian, Typora)"
    $INSTALL_PRINT && info "✓ Impresión (CUPS)"
    $INSTALL_SYNC  && info "✓ Sincronización en la Nube (Dropbox, Megasync)"
    [[ ${#INSTALL_BROWSERS[@]} -gt 0 ]] && info "✓ Navegadores: ${INSTALL_BROWSERS[*]}"
    [[ ${#INSTALL_BROWSERS[@]} -eq 0 ]] && info "  Sin navegadores adicionales"

    echo ""
    confirm "¿Confirmas la instalación?" || die "Instalación cancelada por el usuario."
}

install_optional_packages() {
    step "Instalando paquetes opcionales seleccionados..."
    
    local pkgs=()
    $INSTALL_DEV    && pkgs+=("${PKGS_DEV_OFFICIAL[@]}")
    $INSTALL_QEMU   && pkgs+=("${PKGS_QEMU_OFFICIAL[@]}")
    $INSTALL_OFFICE && pkgs+=("${PKGS_OFFICE_OFFICIAL[@]}")
    $INSTALL_PRINT  && pkgs+=("${PKGS_PRINT_OFFICIAL[@]}")
    
    for b in "${INSTALL_BROWSERS[@]}"; do
        if [[ "$b" == "firefox" ]]; then
            pkgs+=("firefox")
        fi
    done

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        pacman_install "${pkgs[@]}"
    fi

    local aur_pkgs=()
    $INSTALL_DEV    && aur_pkgs+=("${PKGS_DEV_AUR[@]}")
    $INSTALL_OFFICE && aur_pkgs+=("${PKGS_OFFICE_AUR[@]}")
    $INSTALL_SYNC   && aur_pkgs+=("${PKGS_SYNC_AUR[@]}")
    $INSTALL_SPOTIFY && aur_pkgs+=("spotify")
    
    for b in "${INSTALL_BROWSERS[@]}"; do
        if [[ "$b" != "firefox" ]]; then
            aur_pkgs+=("$b")
        fi
    done

    if [[ ${#aur_pkgs[@]} -gt 0 ]]; then
        paru_install "${aur_pkgs[@]}"
    fi
}

# ─── Prerequisitos y Base ────────────────────────────────────────────────────
install_base() {
    step "Instalando paquetes base para Qtile (X11)..."
    # Paquetes CRÍTICOS — sin estos no hay sesión gráfica arrancable
    paru_install xorg-server qtile python-psutil "${PKGS_FILES[@]}"
    ok "Paquetes críticos para sesión X11 instalados"

    # Paquetes no-críticos — cosmética y utilidades
    paru_install --warn python-iwlib feh rofi alacritty pamixer brightnessctl shutter xclip rofi-greenclip simplescreenrecorder ttf-jetbrains-mono-nerd i3lock-color qtile-extras catppuccin-gtk-theme-mocha catppuccin-cursors-mocha papirus-icon-theme fluent-icon-theme vimix-gtk-themes nwg-look python-dbus-fast python-pulsectl python-pulsectl-asyncio dunst htop btop
    if ! pacman -Q picom-ftlabs-git &>/dev/null; then
        $AUR_CMD -S --needed --noconfirm --skipreview picom-ftlabs-git || die "Error instalando picom-ftlabs-git"
    fi
    ok "Paquetes base y Picom instalados."
}

# ─── Applets y Servicios ──────────────────────────────────────────────────────
install_applets() {
    step "Instalando applets, utilidades de red y herramientas del sistema..."
    paru_install network-manager-applet blueman bluez polkit-gnome udiskie redshift xautolock networkmanager-l2tp strongswan xorg-xset snixembed libayatana-appindicator
    sudo systemctl enable --now bluetooth.service
    
    # Polkit SUID
    local helper="/usr/lib/polkit-1/polkit-agent-helper-1"
    if [[ "$(stat -c %a "$helper" 2>/dev/null)" != "4755" ]]; then
        sudo chmod 4755 "$helper"
    fi
    ok "Applets instalados."
}

# ─── Audio ────────────────────────────────────────────────────────────────────
install_audio() {
    step "Instalando soporte de audio avanzado..."
    paru_install pipewire-pulse pamixer pavucontrol
    
    if lspci | grep -Ei "VGA|3D|Display" | grep -qi intel; then
        paru_install sof-firmware
    fi
    systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
    ok "Audio configurado."
}

# ─── Sistema de temas Omarchy (X11) ───────────────────────────────────────────
install_theme_system() {
    step "Instalando sistema de temas Omarchy (X11)..."
    local themes_dir="$HOME/.config/omarchy/themes"
    local current_dir="$HOME/.config/omarchy/current"
    local tpl_dir="$HOME/.local/share/omarchy-local/themed"
    local bg_dir="$HOME/.local/share/backgrounds"
    local bin_dir="$HOME/.local/bin"
    
    mkdir -p "$themes_dir" "$current_dir" "$tpl_dir" "$bg_dir" "$bin_dir"
    
    # Templates para X11
    cat > "$tpl_dir/alacritty-colors.toml.tpl" << 'TPL_EOF'
[colors.primary]
background = "{{ background }}"
foreground = "{{ foreground }}"

[colors.cursor]
text   = "{{ background }}"
cursor = "{{ cursor }}"

[colors.selection]
text       = "{{ selection_foreground }}"
background = "{{ selection_background }}"

[colors.normal]
black   = "{{ color0 }}"
red     = "{{ color1 }}"
green   = "{{ color2 }}"
yellow  = "{{ color3 }}"
blue    = "{{ color4 }}"
magenta = "{{ color5 }}"
cyan    = "{{ color6 }}"
white   = "{{ color7 }}"

[colors.bright]
black   = "{{ color8 }}"
red     = "{{ color9 }}"
green   = "{{ color10 }}"
yellow  = "{{ color11 }}"
blue    = "{{ color12 }}"
magenta = "{{ color13 }}"
cyan    = "{{ color14 }}"
white   = "{{ color15 }}"
TPL_EOF

    cat > "$tpl_dir/qtile-colors.json.tpl" << 'TPL_EOF'
{
    "background": "{{ background }}",
    "foreground": "{{ foreground }}",
    "accent": "{{ accent }}",
    "mantle": "{{ mantle }}",
    "surface": "{{ color0 }}",
    "red": "{{ color1 }}",
    "green": "{{ color2 }}",
    "yellow": "{{ color3 }}",
    "blue": "{{ color4 }}",
    "magenta": "{{ color5 }}",
    "cyan": "{{ color6 }}"
}
TPL_EOF

    cat > "$tpl_dir/rofi.rasi.tpl" << 'TPL_EOF'
* {
    bg:       {{ background }};
    bg-alt:   {{ color0 }};
    fg:       {{ foreground }};
    fg-dim:   {{ color8 }};
    accent:   {{ accent }};
    selected: {{ selection_background }};
}

window {
    width:            35%;
    padding:          0;
    border:           2px solid;
    border-color:     @accent;
    border-radius:    12px;
    background-color: @bg;
}

mainbox {
    padding:          8px;
    background-color: transparent;
}

inputbar {
    padding:          8px 12px;
    margin:           0 0 8px 0;
    border-radius:    8px;
    background-color: @bg-alt;
    children:         [prompt, entry];
}

prompt {
    padding:          0 8px 0 0;
    color:            @accent;
    background-color: transparent;
}

entry {
    color:            @fg;
    background-color: transparent;
}

listview {
    lines:            8;
    columns:          1;
    fixed-height:     false;
    spacing:          4px;
    background-color: transparent;
}

element {
    padding:          8px 12px;
    border-radius:    6px;
    background-color: transparent;
    color:            @fg;
}

element selected {
    background-color: @selected;
    color:            @bg;
}

element-icon {
    size:             24px;
    background-color: transparent;
}

element-text {
    background-color: transparent;
    color:            inherit;
}
TPL_EOF

    cat > "$tpl_dir/eww.scss.tpl" << 'TPL_EOF'
$base:     {{ background }};
$surface0: {{ color0 }};
$surface1: {{ color8 }};
$text:     {{ foreground }};
$accent:   {{ accent }};
$section:  {{ color6 }};

* { font-family: "JetBrainsMono Nerd Font"; font-size: 9pt; }

.sysmon {
  background-color: rgba($base, 0.82);
  padding: 10px 12px;
  border-radius: 10px;
  color: $text;
}

.clock {
  color: $accent;
  font-size: 20pt;
  font-weight: bold;
  margin-bottom: 2px;
}

.date { color: $text; margin-bottom: 6px; }

.divider {
  background-color: $surface1;
  min-height: 1px;
  margin: 4px 0;
}

.divider-thin {
  background-color: $surface0;
  min-height: 1px;
  margin: 1px 0 3px;
}

.section { color: $section; font-weight: bold; margin-top: 2px; }

.srow { margin: 1px 0; }
.key  { color: $text; opacity: 0.65; min-width: 52px; }
.val  { color: $text; }

.sbar {
  margin: 2px 0 4px;
  trough {
    background-color: $surface1;
    border-radius: 3px;
    min-height: 5px;
  }
  highlight, progress {
    background-color: $section;
    border-radius: 3px;
    min-height: 5px;
  }
  slider {
    min-width: 0; min-height: 0;
    background: none; border: none; box-shadow: none;
  }
}
TPL_EOF
    
    cat > "$tpl_dir/dunstrc.tpl" << 'TPL_EOF'
[global]
    frame_color = "{{ accent }}"
    separator_color = frame
    font = JetBrainsMono Nerd Font 10
    corner_radius = 8
    width = 300
    height = 300
    offset = 10x50

[urgency_low]
    background = "{{ background }}"
    foreground = "{{ foreground }}"
    timeout = 10

[urgency_normal]
    background = "{{ background }}"
    foreground = "{{ foreground }}"
    timeout = 10

[urgency_critical]
    background = "{{ color1 }}"
    foreground = "{{ foreground }}"
    frame_color = "{{ color1 }}"
    timeout = 0
TPL_EOF

    # ── Script theme-apply (Adaptado para X11/Qtile/Dunst) ──
    cat > "$bin_dir/theme-apply" << 'APPLY_EOF'
#!/usr/bin/env bash
set -euo pipefail

THEME="${1:-$(cat "${HOME}/.config/omarchy/current/theme" 2>/dev/null || echo catppuccin)}"
THEMES_DIR="${HOME}/.config/omarchy/themes"
CURRENT_DIR="${HOME}/.config/omarchy/current"
TEMPLATES_DIR="${HOME}/.local/share/omarchy-local/themed"
COLORS_FILE="${THEMES_DIR}/${THEME}/colors.toml"

[[ -f "$COLORS_FILE" ]] || { echo "Tema '$THEME' no encontrado: $COLORS_FILE" >&2; exit 1; }

_val() { grep "^${1}[[:space:]]*=" "$COLORS_FILE" | sed 's/.*= *"\(.*\)"/\1/'; }
_opt() { grep "^${1}[[:space:]]*=" "$COLORS_FILE" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' || true; }

wallpaper=$(_val wallpaper)
accent=$(_val accent);               cursor=$(_val cursor)
foreground=$(_val foreground);       background=$(_val background)
mantle=$(_val mantle)
selection_foreground=$(_val selection_foreground)
selection_background=$(_val selection_background)
color0=$(_val color0);   color1=$(_val color1);   color2=$(_val color2);   color3=$(_val color3)
color4=$(_val color4);   color5=$(_val color5);   color6=$(_val color6);   color7=$(_val color7)
color8=$(_val color8);   color9=$(_val color9);   color10=$(_val color10); color11=$(_val color11)
color12=$(_val color12); color13=$(_val color13); color14=$(_val color14); color15=$(_val color15)

accent_strip="${accent#\#}";      background_strip="${background#\#}"
foreground_strip="${foreground#\#}"; color0_strip="${color0#\#}"; color2_strip="${color2#\#}"

SED_ARGS=(
    -e "s|{{ accent }}|${accent}|g"
    -e "s|{{ cursor }}|${cursor}|g"
    -e "s|{{ foreground }}|${foreground}|g"
    -e "s|{{ background }}|${background}|g"
    -e "s|{{ mantle }}|${mantle}|g"
    -e "s|{{ selection_foreground }}|${selection_foreground}|g"
    -e "s|{{ selection_background }}|${selection_background}|g"
    -e "s|{{ color0 }}|${color0}|g"   -e "s|{{ color1 }}|${color1}|g"
    -e "s|{{ color2 }}|${color2}|g"   -e "s|{{ color3 }}|${color3}|g"
    -e "s|{{ color4 }}|${color4}|g"   -e "s|{{ color5 }}|${color5}|g"
    -e "s|{{ color6 }}|${color6}|g"   -e "s|{{ color7 }}|${color7}|g"
    -e "s|{{ color8 }}|${color8}|g"   -e "s|{{ color9 }}|${color9}|g"
    -e "s|{{ color10 }}|${color10}|g" -e "s|{{ color11 }}|${color11}|g"
    -e "s|{{ color12 }}|${color12}|g" -e "s|{{ color13 }}|${color13}|g"
    -e "s|{{ color14 }}|${color14}|g" -e "s|{{ color15 }}|${color15}|g"
)

sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/alacritty-colors.toml.tpl" > "${CURRENT_DIR}/alacritty-colors.toml"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/rofi.rasi.tpl"             > "${CURRENT_DIR}/rofi.rasi"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/eww.scss.tpl"              > "${HOME}/.config/eww/eww.scss"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/qtile-colors.json.tpl"     > "${CURRENT_DIR}/qtile-colors.json"
mkdir -p "${HOME}/.config/dunst"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/dunstrc.tpl"               > "${HOME}/.config/dunst/dunstrc"

if pgrep -x dunst >/dev/null 2>&1; then
    killall dunst
    nohup dunst >/dev/null 2>&1 &
fi

# GTK
gtk_theme_field=$(_opt gtk_theme)
color_scheme_field=$(_opt color_scheme)
cursor_theme_field=$(_opt cursor_theme)
icon_theme_field=$(_opt icon_theme)

if [[ -n "${gtk_theme_field:-}" ]]; then
    gsettings set org.gnome.desktop.interface gtk-theme    "$gtk_theme_field" 2>/dev/null || true
    [[ -n "${color_scheme_field:-}" ]] && gsettings set org.gnome.desktop.interface color-scheme  "$color_scheme_field" 2>/dev/null || true
    [[ -n "${cursor_theme_field:-}" ]] && gsettings set org.gnome.desktop.interface cursor-theme  "$cursor_theme_field" 2>/dev/null || true
    [[ -n "${icon_theme_field:-}" ]]   && gsettings set org.gnome.desktop.interface icon-theme    "$icon_theme_field"   2>/dev/null || true
fi

[[ -n "${wallpaper:-}" ]] && echo "$wallpaper" > "${CURRENT_DIR}/background"

if [[ -n "${DISPLAY:-}" ]]; then
    if [[ -n "${wallpaper:-}" && -f "$wallpaper" ]]; then
        feh --bg-fill "$wallpaper" &
    fi
    # Recargar Qtile
    qtile cmd-obj -o cmd -f reload_config 2>/dev/null || true
    # Recargar Eww
    if pgrep -x eww >/dev/null 2>&1; then
        eww reload 2>/dev/null || true
    else
        nohup eww open sysmon >/dev/null 2>&1 &
    fi
fi

echo "$THEME" > "${CURRENT_DIR}/theme"
echo "Tema '${THEME}' aplicado."
APPLY_EOF
    chmod +x "$bin_dir/theme-apply"

    # ── Script theme-switcher ──
    cat > "$bin_dir/theme-switcher" << 'SWITCHER_EOF'
#!/usr/bin/env bash
set -euo pipefail
THEMES_DIR="${HOME}/.config/omarchy/themes"
TEMA=$(ls "$THEMES_DIR" | rofi -dmenu -p "Tema" -i -theme-str 'window {width: 300px;}')
[[ -z "$TEMA" ]] && exit 0
"${HOME}/.local/bin/theme-apply" "$TEMA"
SWITCHER_EOF
    chmod +x "$bin_dir/theme-switcher"
    
    # ── Clonar Wallpapers Omarchy ──
    local clone_dir="/tmp/omarchy-themes-$$"
    if command -v git &>/dev/null; then
        rm -rf "$clone_dir"
        git clone --depth=1 -b dev --filter=blob:none --sparse \
            https://github.com/basecamp/omarchy "$clone_dir" 2>/dev/null \
            && git -C "$clone_dir" sparse-checkout set themes/ 2>/dev/null \
            && ok "Repo Omarchy clonado en $clone_dir" \
            || { warn "No se pudo clonar repo Omarchy — agrega wallpapers manualmente en $bg_dir"; rm -rf "$clone_dir"; clone_dir=""; }
    fi

    if [[ -n "${clone_dir:-}" && -d "$clone_dir/themes" ]]; then
        local tema_dir tema_name bg_file bg_name first_bg colors_src
        local accent cursor fg bg mantle sel_fg sel_bg
        local c0 c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11 c12 c13 c14 c15
        local wall_file wall_path

        _omarchy_val() { grep "^${1}[[:space:]]*=" "$2" | sed 's/.*= *"\(.*\)"/\1/'; }

        for tema_dir in "$clone_dir/themes"/*/; do
            [[ -d "$tema_dir" ]] || continue
            tema_name=$(basename "$tema_dir")
            [[ "$tema_name" == "bin" ]] && continue
            [[ "$tema_name" == "catppuccin" ]] && tema_name="catppuccin-mocha"

            mkdir -p "$themes_dir/$tema_name"

            # Copiar wallpapers
            first_bg=""
            if [[ -d "$tema_dir/backgrounds" ]]; then
                for bg_file in "$tema_dir/backgrounds/"*; do
                    [[ -f "$bg_file" ]] || continue
                    bg_name=$(basename "$bg_file")
                    [[ "$bg_name" == "omarchy.png" ]] && continue
                    cp "$bg_file" "$bg_dir/omarchy-${tema_name}-${bg_name}"
                    [[ -z "$first_bg" ]] && first_bg="$bg_name"
                done
            fi

            # Determinar primer wallpaper (orden alfabético, excluye omarchy.png)
            if [[ -d "$tema_dir/backgrounds" ]]; then
                wall_file=$(ls "$tema_dir/backgrounds/" 2>/dev/null \
                    | grep -v "^omarchy\.png$" | sort | head -1)
                wall_path="${bg_dir}/omarchy-${tema_name}-${wall_file}"
            else
                wall_path=""
            fi

            # Crear colors.toml solo si no existe ya
            if [[ -f "$themes_dir/$tema_name/colors.toml" ]]; then
                ok "  $tema_name: colors.toml ya presente"
                continue
            fi

            colors_src="$tema_dir/colors.toml"
            if [[ ! -f "$colors_src" ]]; then
                warn "  $tema_name: sin colors.toml en el repo — crea $themes_dir/$tema_name/colors.toml manualmente"
                continue
            fi

            accent=$(_omarchy_val accent    "$colors_src")
            cursor=$(_omarchy_val cursor    "$colors_src")
            fg=$(_omarchy_val foreground    "$colors_src")
            bg=$(_omarchy_val background    "$colors_src")
            mantle=$(_omarchy_val mantle    "$colors_src")
            [[ -z "$mantle" ]] && mantle="$bg"
            sel_fg=$(_omarchy_val selection_foreground "$colors_src")
            sel_bg=$(_omarchy_val selection_background "$colors_src")
            c0=$(_omarchy_val  color0  "$colors_src"); c1=$(_omarchy_val  color1  "$colors_src")
            c2=$(_omarchy_val  color2  "$colors_src"); c3=$(_omarchy_val  color3  "$colors_src")
            c4=$(_omarchy_val  color4  "$colors_src"); c5=$(_omarchy_val  color5  "$colors_src")
            c6=$(_omarchy_val  color6  "$colors_src"); c7=$(_omarchy_val  color7  "$colors_src")
            c8=$(_omarchy_val  color8  "$colors_src"); c9=$(_omarchy_val  color9  "$colors_src")
            c10=$(_omarchy_val color10 "$colors_src"); c11=$(_omarchy_val color11 "$colors_src")
            c12=$(_omarchy_val color12 "$colors_src"); c13=$(_omarchy_val color13 "$colors_src")
            c14=$(_omarchy_val color14 "$colors_src"); c15=$(_omarchy_val color15 "$colors_src")

            bg_hex="${bg#\#}"
            bg_r=$((16#${bg_hex:0:2}))
            if (( bg_r > 127 )); then
                case "$tema_name" in
                    catppuccin-latte)
                        gtk_t="catppuccin-latte-mauve-standard+default"
                        cur_t="catppuccin-latte-dark-cursors"
                        ;;
                    *)
                        gtk_t="Adwaita"
                        cur_t=""
                        ;;
                esac
                ico_t="Papirus"
                col_s="prefer-light"
            else
                gtk_t="catppuccin-mocha-mauve-standard+default"
                cur_t="catppuccin-mocha-dark-cursors"
                ico_t="Papirus-Dark"
                col_s="prefer-dark"
            fi

            cat > "$themes_dir/$tema_name/colors.toml" << COLORS_EOF
wallpaper = "${wall_path}"

accent = "${accent}"
cursor = "${cursor}"
foreground = "${fg}"
background = "${bg}"
mantle = "${mantle}"
selection_foreground = "${sel_fg}"
selection_background = "${sel_bg}"

color0  = "${c0}"
color1  = "${c1}"
color2  = "${c2}"
color3  = "${c3}"
color4  = "${c4}"
color5  = "${c5}"
color6  = "${c6}"
color7  = "${c7}"
color8  = "${c8}"
color9  = "${c9}"
color10 = "${c10}"
color11 = "${c11}"
color12 = "${c12}"
color13 = "${c13}"
color14 = "${c14}"
color15 = "${c15}"
gtk_theme    = "${gtk_t}"
cursor_theme = "${cur_t}"
icon_theme   = "${ico_t}"
color_scheme = "${col_s}"
COLORS_EOF
            ok "  $tema_name: colors.toml creado"
        done
        unset -f _omarchy_val
        rm -rf "$clone_dir"
        ok "Wallpapers y colors.toml instalados"
    fi
    
    # Aplicar catppuccin-mocha por defecto
    if [[ ! -f "$current_dir/theme" ]]; then
        "$bin_dir/theme-apply" "catppuccin-mocha" || true
    fi
    ok "Sistema de temas configurado."
}

# ─── Eww (Sysmon X11) ─────────────────────────────────────────────────────────
install_eww() {
    step "Instalando eww (monitor del sistema X11)..."
    sudo -v

    local apps_dir="$HOME/.local/share/applications"
    local bin="$HOME/.local/bin"
    mkdir -p "$apps_dir" "$bin" ~/.config/eww

    # Paquetes
    pacman_install intel-gpu-tools
    ok "intel-gpu-tools instalado"

    paru_install eww dart-sass

    # Nombres de red estilo clásico (eth0/wlan0) vía parámetros del kernel
    if grep -q 'net.ifnames=0' /etc/default/grub 2>/dev/null; then
        ok "net.ifnames=0 ya configurado en GRUB"
    else
        sudo sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 net.ifnames=0 biosdevname=0"/' /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        warn "net.ifnames=0 aplicado — reinicia el equipo para que eth0/wlan0 sean efectivos"
    fi

    # Sudoers para intel_gpu_top sin contraseña
    if ! sudo grep -q 'intel_gpu_top' /etc/sudoers.d/intel-gpu-top 2>/dev/null; then
        echo "${USER} ALL=(root) NOPASSWD: /usr/bin/intel_gpu_top" \
            | sudo tee /etc/sudoers.d/intel-gpu-top > /dev/null
        sudo chmod 440 /etc/sudoers.d/intel-gpu-top
        ok "sudoers intel_gpu_top configurado"
    else
        ok "sudoers intel_gpu_top ya existe"
    fi

    # ── Scripts de datos ──────────────────────────────────────────────────────

    # eww-sysinfo — JSON con CPU/RAM/disco/red/GPU (se ejecuta cada 3s)
    sudo tee /usr/local/bin/eww-sysinfo > /dev/null << 'PYEOF'
#!/usr/bin/env python3
import subprocess, json, os, glob, time, re

def run(cmd, default="N/A"):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, timeout=3).strip() or default
    except Exception:
        return default

def cpu_pct():
    try:
        with open('/proc/stat') as f:
            l1 = f.readline().split()
        time.sleep(0.3)
        with open('/proc/stat') as f:
            l2 = f.readline().split()
        t1 = sum(int(x) for x in l1[1:]); i1 = int(l1[5])
        t2 = sum(int(x) for x in l2[1:]); i2 = int(l2[5])
        dt = t2 - t1
        return int((1 - (i2 - i1) / dt) * 100) if dt else 0
    except Exception:
        return 0

def hwmon_temp(sensor_name):
    for f in glob.glob('/sys/class/hwmon/*/name'):
        try:
            if open(f).read().strip() == sensor_name:
                t = open(os.path.join(os.path.dirname(f), 'temp1_input')).read()
                return int(int(t) / 1000)
        except Exception:
            pass
    return "N/A"

def cpu_freq():
    try:
        freqs = [float(l.split(':')[1]) for l in open('/proc/cpuinfo') if l.startswith('cpu MHz')]
        return f"{sum(freqs)/len(freqs)/1000:.2f}" if freqs else "N/A"
    except Exception:
        return "N/A"

def mem_info():
    try:
        d = {}
        for l in open('/proc/meminfo'):
            k, v = l.split(':')
            d[k.strip()] = int(v.split()[0])
        total = d['MemTotal']; used = total - d['MemAvailable']
        st = d.get('SwapTotal', 0); sf = d.get('SwapFree', 0)
        def fmt(kb):
            if kb >= 1048576: return f"{kb/1048576:.1f}G"
            if kb >= 1024:    return f"{kb/1024:.0f}M"
            return f"{kb}K"
        return {"ram_used": fmt(used), "ram_total": fmt(total),
                "ram_pct": int(used/total*100),
                "swap_used": fmt(st - sf), "swap_total": fmt(st)}
    except Exception:
        return {"ram_used":"N/A","ram_total":"N/A","ram_pct":0,"swap_used":"N/A","swap_total":"N/A"}

def disk_info():
    try:
        import shutil
        st = shutil.disk_usage('/')
        def fmt(b):
            if b >= 1e12: return f"{b/1e12:.1f}T"
            if b >= 1e9:  return f"{b/1e9:.0f}G"
            if b >= 1e6:  return f"{b/1e6:.0f}M"
            return f"{int(b)}B"
        return {"disk_used": fmt(st.used), "disk_total": fmt(st.total),
                "disk_pct": int(st.used/st.total*100)}
    except Exception:
        return {"disk_used":"N/A","disk_total":"N/A","disk_pct":0}

def net_info():
    try:
        iface = run("ip -br link | awk '$2==\"UP\" && $1!=\"lo\" {print $1; exit}'")
        lan4  = run(f"ip -4 addr show {iface} | awk '/inet /{{print $2}}' | cut -d/ -f1 | head -1")
        lan6  = run(f"ip -6 addr show {iface} scope link | awk '/inet6/{{print $2}}' | cut -d/ -f1 | head -1")
        return {"iface": iface, "lan4": lan4 or "N/A", "lan6": lan6 or "N/A"}
    except Exception:
        return {"iface":"N/A","lan4":"N/A","lan6":"N/A"}

def gpu_info():
    try:
        r = subprocess.run(['timeout','1.5s','sudo','intel_gpu_top','-s','500','-J'],
                           capture_output=True, text=True, timeout=3)
        for obj in reversed(re.split(r'\},\s*\{', r.stdout)):
            obj = obj.strip().lstrip('[').rstrip(']').strip()
            if not obj.startswith('{'): obj = '{' + obj
            if not obj.endswith('}'): obj = obj + '}'
            try:
                d = json.loads(obj)
                if 'engines' in d and 'frequency' in d:
                    rnd = d['engines'].get('Render/3D',{}).get('busy',0)
                    frq = d['frequency'].get('actual',0)
                    pg  = d['power'].get('GPU',0)
                    pp  = d['power'].get('Package',0)
                    rc6 = d.get('rc6',{}).get('value',0)
                    return {"gpu_render": f"{rnd:.0f}%  RC6 {rc6:.0f}%",
                            "gpu_freq":   f"{frq:.0f} MHz",
                            "gpu_power":  f"{pg:.1f}W GPU / {pp:.1f}W total"}
            except Exception:
                continue
    except Exception:
        pass
    return {"gpu_render":"N/A","gpu_freq":"N/A","gpu_power":"N/A"}

out = {"cpu_pct": cpu_pct(), "cpu_temp": hwmon_temp('coretemp'),
       "cpu_freq": cpu_freq(), "nvme_temp": hwmon_temp('nvme')}
out.update(mem_info())
out.update(disk_info())
out.update(net_info())
out.update(gpu_info())
print(json.dumps(out))
PYEOF
    sudo chmod +x /usr/local/bin/eww-sysinfo
    ok "eww-sysinfo instalado"

    # eww-net-speed — JSON {"up":"Xk","dn":"Xk"} (duerme 1s internamente)
    sudo tee /usr/local/bin/eww-net-speed > /dev/null << 'NETEOF'
#!/bin/bash
IFACE=$(ip -br link | awk '$2=="UP" && $1!="lo" {print $1; exit}')
f="/sys/class/net/$IFACE/statistics"
r1=$(cat "$f/rx_bytes" 2>/dev/null || echo 0)
t1=$(cat "$f/tx_bytes" 2>/dev/null || echo 0)
sleep 1
r2=$(cat "$f/rx_bytes" 2>/dev/null || echo 0)
t2=$(cat "$f/tx_bytes" 2>/dev/null || echo 0)
h() {
    local bits=$(( $1 * 8 ))
    if   [ "$bits" -ge 1000000 ]; then awk -v b="$bits" 'BEGIN{printf "%.1f Mbps", b/1000000}'
    elif [ "$bits" -ge 1000 ];    then printf "%d Kbps" $(( bits / 1000 ))
    else printf "%d bps" "$bits"; fi
}
printf '{"up":"%s","dn":"%s"}' "$(h $((t2-t1)))" "$(h $((r2-r1)))"
NETEOF
    sudo chmod +x /usr/local/bin/eww-net-speed
    ok "eww-net-speed instalado"

    # eww-wan — JSON {"wan4":"x","wan6":"x"} (lento, se refresca cada 5 min)
    sudo tee /usr/local/bin/eww-wan > /dev/null << 'WANEOF'
#!/bin/bash
wan4=$(curl -s4 --max-time 8 ifconfig.me 2>/dev/null || echo "N/A")
wan6=$(curl -s6 --max-time 8 ifconfig.me 2>/dev/null || echo "N/A")
printf '{"wan4":"%s","wan6":"%s"}' "$wan4" "$wan6"
WANEOF
    sudo chmod +x /usr/local/bin/eww-wan
    ok "eww-wan instalado"

    # ── eww.yuck ──────────────────────────────────────────────────────────────
    cat > ~/.config/eww/eww.yuck << 'YUCKEOF'
;; Datos rápidos (3s)
(defpoll data :interval "3s" `/usr/local/bin/eww-sysinfo`)
;; Velocidad de red (2s efectivos tras sleep 1 interno)
(defpoll netspeed :interval "2s" `/usr/local/bin/eww-net-speed`)
;; IP pública (cada 5 min)
(defpoll wan :interval "300s" `/usr/local/bin/eww-wan`)
;; Hora y fecha (rápidos, separados)
(defpoll clock :interval "1s" `date +'%H:%M:%S'`)
(defpoll datestr :interval "60s" `date +'%A %d %B %Y'`)

;; Widgets auxiliares
(defwidget srow [key val]
  (box :orientation "horizontal" :space-evenly false :class "srow"
    (label :class "key" :text key :halign "start" :xalign 0)
    (label :class "val" :text val :halign "end" :hexpand true :xalign 1 :truncate true)))

(defwidget sbar [value]
  (scale :min 0 :max 100 :active false :value value :class "sbar"))

(defwidget ssection [title]
  (label :class "section" :text title :halign "start" :xalign 0))

;; Widget principal
(defwidget sysmon []
  (box :orientation "vertical" :space-evenly false :class "sysmon"

    (label :class "clock" :text clock :halign "center")
    (label :class "date"  :text datestr :halign "center")
    (box :class "divider" :vexpand false)

    (ssection :title "CPU")
    (box :class "divider-thin")
    (srow :key "Uso  " :val "${data.cpu_pct}%")
    (sbar :value {data.cpu_pct})
    (srow :key "Temp " :val "${data.cpu_temp}°C")
    (srow :key "Frec " :val "${data.cpu_freq} GHz")
    (box :class "divider")

    (ssection :title "MEMORIA")
    (box :class "divider-thin")
    (srow :key "RAM  " :val "${data.ram_used} / ${data.ram_total}")
    (sbar :value {data.ram_pct})
    (srow :key "Swap " :val "${data.swap_used} / ${data.swap_total}")
    (box :class "divider")

    (ssection :title "DISCO  (pool BTRFS)")
    (box :class "divider-thin")
    (srow :key "Usado" :val "${data.disk_used} / ${data.disk_total}")
    (sbar :value {data.disk_pct})
    (srow :key "NVMe " :val "${data.nvme_temp}°C")
    (box :class "divider")

    (ssection :title "RED  —  ${data.iface}")
    (box :class "divider-thin")
    (srow :key "LAN  " :val {data.lan4})
    (srow :key "LAN6 " :val {data.lan6})
    (srow :key "WAN4 " :val {wan.wan4})
    (srow :key "WAN6 " :val {wan.wan6})
    (srow :key "Vel  " :val "UP ${netspeed.up}  DN ${netspeed.dn}")
    (box :class "divider")

    (ssection :title "GPU  Intel Iris Xe")
    (box :class "divider-thin")
    (srow :key "Render" :val {data.gpu_render})
    (srow :key "Frec  " :val {data.gpu_freq})
    (srow :key "Pot   " :val {data.gpu_power})
  )
)

;; Ventana — layer bottom: por debajo de todas las ventanas, todos los workspaces
(defwindow sysmon
  :monitor 0
  :geometry (geometry :x "1620px" :y "50px" :width "255px" :anchor "top left")
  :stacking "bottom"
  :windowtype "normal"
  :wm-ignore true
  :exclusive false
  :focusable false
  (sysmon))
YUCKEOF
    ok "~/.config/eww/eww.yuck creado"
    ok "Eww configurado e instalado."
}

# ─── Idle y Lockscreen ────────────────────────────────────────────────────────
install_idle() {
    step "Configurando idle-settings (X11)..."
    local bin_dir="$HOME/.local/bin"
    
    cat > "$bin_dir/idle-settings" << 'IDLE_EOF'
#!/bin/bash
# idle-settings (X11 Edition using xautolock and xset)

TIMEOUT_FILE="$HOME/.config/omarchy/current/idle_timeout.json"
CACHE_CMD="$HOME/.cache/qtile-idle-command.sh"

hibernate_supported() {
    grep -qw disk /sys/power/state 2>/dev/null || return 1
    [[ -n "$(swapon --noheadings --show=NAME 2>/dev/null)" ]] || return 1
}

to_seconds() {
    case "$1" in
        "5 minutos")   echo 300  ;;
        "10 minutos")  echo 600  ;;
        "15 minutos")  echo 900  ;;
        "20 minutos")  echo 1200 ;;
        "30 minutos")  echo 1800 ;;
        "60 minutos")  echo 3600 ;;
        "120 minutos") echo 7200 ;;
        "Nunca")       echo 0    ;;
        *)             echo -1   ;;
    esac
}

rofi_pick() {
    printf "5 minutos\n10 minutos\n15 minutos\n20 minutos\n30 minutos\n60 minutos\n120 minutos\nNunca" \
        | rofi -dmenu -p "$1" -theme-str 'window {width: 280px;} listview {lines: 8;}'
}

rofi_action() {
    if hibernate_supported; then
        printf "Suspender\nHibernar\nNinguna"
    else
        printf "Suspender\nNinguna"
    fi | rofi -dmenu -p "$1" -theme-str 'window {width: 260px;} listview {lines: 3;}'
}

# Leer valores actuales (por defecto o desde json)
lock_min=10
action_cur="Ninguna"
action_min=30

if [[ -f "$TIMEOUT_FILE" ]]; then
    lock_min=$(grep -o '"lock_min": *[0-9]*' "$TIMEOUT_FILE" | awk '{print $2}')
    action_cur=$(grep -o '"action": *"[^"]*"' "$TIMEOUT_FILE" | cut -d'"' -f4)
    action_min=$(grep -o '"action_min": *[0-9]*' "$TIMEOUT_FILE" | awk '{print $2}')
fi

lock_min=${lock_min:-10}
action_cur=${action_cur:-Ninguna}
action_min=${action_min:-30}

# 1) Elegir tiempo de bloqueo
lock_choice=$(rofi_pick "Bloquear pantalla  [actual: ${lock_min} min]")
[[ -z "$lock_choice" ]] && exit 0
lock_sec=$(to_seconds "$lock_choice")
[[ $lock_sec -eq -1 ]] && exit 1
lock_min=$(( lock_sec / 60 ))

# 2) Elegir acción de energía
action_choice=$(rofi_action "Acción de energía  [actual: ${action_cur}]")
[[ -z "$action_choice" ]] && exit 0

# 3) Elegir tiempo de acción
action_sec=0
action_min=0
if [[ "$action_choice" != "Ninguna" ]]; then
    action_time_choice=$(rofi_pick "${action_choice}  [actual: ${action_min} min]")
    [[ -z "$action_time_choice" ]] && exit 0
    action_sec=$(to_seconds "$action_time_choice")
    [[ $action_sec -eq -1 ]] && exit 1
    action_min=$(( action_sec / 60 ))

    if [[ $lock_sec -gt 0 && $action_sec -gt 0 && $action_sec -le $lock_sec ]]; then
        notify-send "Pantalla y energía" \
            "El tiempo de ${action_choice,,} debe ser mayor al de bloqueo." --urgency=critical
        exit 1
    fi
fi

# Calcular DPMS (apagar pantalla): 5 minutos (300s) después del bloqueo
dpms_sec=0
if [[ $lock_sec -gt 0 ]]; then
    candidate=$(( lock_sec + 300 ))
    if [[ $action_sec -eq 0 || $candidate -lt $action_sec ]]; then
        dpms_sec=$candidate
    fi
fi

# Guardar estado en JSON
mkdir -p "$(dirname "$TIMEOUT_FILE")"
cat > "$TIMEOUT_FILE" << EOF
{
  "lock_min": $lock_min,
  "action": "$action_choice",
  "action_min": $action_min
}
EOF

# Generar el script de comando
cat > "$CACHE_CMD" << EOF
#!/bin/bash
# Generado automáticamente por idle-settings
killall xautolock 2>/dev/null || true

# Configurar DPMS (Apagar pantalla)
if [[ $dpms_sec -gt 0 ]]; then
    xset +dpms
    xset dpms \$dpms_sec \$dpms_sec \$dpms_sec
else
    xset -dpms
fi

# Configurar Bloqueo y Acción de Energía
if [[ $lock_min -gt 0 ]]; then
    if [[ "$action_choice" == "Suspender" && $action_min -gt $lock_min ]]; then
        delta=\$(( action_min - lock_min ))
        nohup xautolock -detectdelay 1 -time \$lock_min -locker "qtile-lock" -killtime \$delta -killer "systemctl suspend" >/dev/null 2>&1 &
    elif [[ "$action_choice" == "Hibernar" && $action_min -gt $lock_min ]]; then
        delta=\$(( action_min - lock_min ))
        nohup xautolock -detectdelay 1 -time \$lock_min -locker "qtile-lock" -killtime \$delta -killer "systemctl hibernate" >/dev/null 2>&1 &
    else
        nohup xautolock -detectdelay 1 -time \$lock_min -locker "qtile-lock" >/dev/null 2>&1 &
    fi
elif [[ $lock_min -eq 0 && "$action_choice" != "Ninguna" && $action_min -gt 0 ]]; then
    cmd="systemctl suspend"
    [[ "$action_choice" == "Hibernar" ]] && cmd="systemctl hibernate"
    nohup xautolock -detectdelay 1 -time \$action_min -locker "\$cmd" >/dev/null 2>&1 &
fi
EOF

chmod +x "$CACHE_CMD"
bash "$CACHE_CMD"

if [[ $lock_min -gt 0 ]]; then
    if [[ "$action_choice" != "Ninguna" ]]; then
        notify-send "Energía" "Bloqueo a los $lock_min min. Pantalla off a los \$(( dpms_sec / 60 )) min. ${action_choice} a los $action_min min."
    else
        notify-send "Energía" "Bloqueo fijado en $lock_min minutos. Pantalla off a los \$(( dpms_sec / 60 )) min."
    fi
else
    if [[ "$action_choice" != "Ninguna" ]]; then
        notify-send "Energía" "Bloqueo desactivado. ${action_choice} a los $action_min min."
    else
        notify-send "Energía" "Bloqueo y suspensión automáticos desactivados."
    fi
fi
IDLE_EOF
    chmod +x "$bin_dir/idle-settings"
    ok "idle-settings instalado."
}

# ─── kb-switch (X11) ──────────────────────────────────────────────────────────
install_kb_switch() {
    step "Instalando kb-switch (X11)..."
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    cat > "$bin_dir/kb-switch" << 'EOF'
#!/bin/bash
# kb-switch — cicla entre 3 layouts: US Internacional, Español Latam, Español España

STATE_FILE="$HOME/.cache/kb-switch-state"
LAYOUTS=(us:intl latam: es:)
LABELS=("US Internacional (con acentos)" "Español Latinoamérica" "Español España")

current=0
[[ -f "$STATE_FILE" ]] && current=$(cat "$STATE_FILE")
next=$(( (current + 1) % 3 ))

IFS=':' read -r layout variant <<< "${LAYOUTS[$next]}"

if pgrep -x Hyprland >/dev/null 2>&1; then
    hyprctl keyword input:kb_layout "$layout" >/dev/null
    hyprctl keyword input:kb_variant "$variant" >/dev/null
else
    setxkbmap -layout "$layout" -variant "$variant"
fi

echo "$next" > "$STATE_FILE"
notify-send "Teclado" "${LABELS[$next]}" -t 2000
EOF
    chmod +x "$bin_dir/kb-switch"
    ok "kb-switch instalado."

    # Seed initial STATE_FILE based on detected system layout
    detect_keyboard_layout
    local initial_state=0  # Default: US Internacional
    if [[ "$SYS_KB_LAYOUT" == "latam" ]]; then
        initial_state=1
    elif [[ "$SYS_KB_LAYOUT" == "es" ]]; then
        initial_state=2
    fi
    mkdir -p "$HOME/.cache"
    echo "$initial_state" > "$HOME/.cache/kb-switch-state"
    ok "kb-switch STATE_FILE inicializado a: índice $initial_state (layout=$SYS_KB_LAYOUT)"
}

# ─── GRUB Bootloader ─────────────────────────────────────────────────────
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

# ─── Display Manager ──────────────────────────────────────────────────────
install_sddm() {
    step "Instalando y habilitando SDDM (display manager)..."

    # Instalar SDDM oficial
    if ! pacman -Q sddm &>/dev/null; then
        sudo pacman -S --needed --noconfirm sddm || die "Error instalando sddm"
    fi
    ok "SDDM oficial instalado"

    # Instalar tema AUR (sddm-astronaut-theme + dependencias)
    paru_install sddm-astronaut-theme woff2-font-awesome

    # Verificar que el tema se instaló correctamente
    if ! pacman -Qq sddm-astronaut-theme &>/dev/null; then
        die "sddm-astronaut-theme no se pudo instalar — requerido para consistencia visual"
    fi
    ok "SDDM con tema astronaut instalado"

    # Configurar SDDM para usar el tema astronaut
    sudo mkdir -p /etc/sddm.conf.d
    echo "[Theme]" | sudo tee /etc/sddm.conf.d/qtile.conf > /dev/null
    echo "Current=sddm-astronaut-theme" | sudo tee -a /etc/sddm.conf.d/qtile.conf > /dev/null
    ok "SDDM configurado para usar tema sddm-astronaut-theme"

    # Copiar configuración del tema si no existe
    if [[ ! -f /etc/sddm.conf.d/sddm-astronaut-theme.conf ]] && [[ -f /usr/share/sddm/themes/sddm-astronaut-theme/theme.conf ]]; then
        sudo cp /usr/share/sddm/themes/sddm-astronaut-theme/theme.conf /etc/sddm.conf.d/sddm-astronaut-theme.conf
        ok "Configuración de tema copiada"
    fi

    # Habilitar SDDM
    if ! systemctl is-enabled --quiet sddm.service 2>/dev/null; then
        sudo systemctl enable sddm.service
    fi
    ok "SDDM habilitado para inicialización en boot"
}

# ─── Configuraciones Finales ──────────────────────────────────────────────────
copy_configs() {
    command -v qtile &>/dev/null || die "El binario 'qtile' no está disponible — install_base() falló silenciosamente. Revisa el log y reinstala: paru -S qtile"
    step "Copiando configuraciones de Qtile..."
    mkdir -p ~/.config/qtile ~/.config/picom ~/.config/rofi ~/.config/alacritty ~/.local/bin
    
    cp -r "$CONFIG_DIR/rofi" ~/.config/ || true
    cp -r "$CONFIG_DIR/alacritty" ~/.config/ || true
    cp "$CONFIG_DIR/picom/picom.conf" ~/.config/picom/picom.conf
    cp "$CONFIG_DIR/qtile/config.py" ~/.config/qtile/config.py
    if [[ "$FILE_MANAGER" == "thunar" ]]; then
        sed -i 's/"nautilus"/"thunar"/g' ~/.config/qtile/config.py
        ok "config.py actualizado: gestor de archivos configurado como thunar"
    fi
    cp "$CONFIG_DIR/qtile/autostart.sh" ~/.config/qtile/autostart.sh
    cp "$CONFIG_DIR/qtile/qtile-lock" ~/.local/bin/qtile-lock
    chmod +x ~/.local/bin/qtile-lock
    cp "$CONFIG_DIR/qtile/qtile-exit" ~/.local/bin/qtile-exit
    chmod +x ~/.local/bin/qtile-exit
    cp "$CONFIG_DIR/qtile/qtile-monitor-setup" ~/.local/bin/qtile-monitor-setup
    chmod +x ~/.local/bin/qtile-monitor-setup
    cp "$CONFIG_DIR/qtile/qtile-monitor-listener" ~/.local/bin/qtile-monitor-listener
    chmod +x ~/.local/bin/qtile-monitor-listener
    cp "$CONFIG_DIR/qtile/qtile-keyboard-setup" ~/.local/bin/qtile-keyboard-setup
    chmod +x ~/.local/bin/qtile-keyboard-setup
    cp "$CONFIG_DIR/qtile/show-keys" ~/.local/bin/show-keys
    chmod +x ~/.local/bin/show-keys
    mkdir -p ~/.local/share/applications
    cp "$CONFIG_DIR/qtile/qtile-keyboard-setup.desktop" ~/.local/share/applications/qtile-keyboard-setup.desktop
    cp "$CONFIG_DIR/qtile/qtile-monitor-setup.desktop" ~/.local/share/applications/qtile-monitor-setup.desktop
    cp "$CONFIG_DIR/qtile/qtile-audio-setup.desktop" ~/.local/share/applications/qtile-audio-setup.desktop
    cp "$CONFIG_DIR/qtile/qtile-exit.desktop" ~/.local/share/applications/qtile-exit.desktop
    cp "$CONFIG_DIR/qtile/show-keys.desktop" ~/.local/share/applications/show-keys.desktop
    cp "$CONFIG_DIR/qtile/idle-settings.desktop" ~/.local/share/applications/idle-settings.desktop
    
    # Asegurar que las rutas de los archivos .desktop apunten a la ruta absoluta de home
    sed -i "s|Exec=~/|Exec=$HOME/|g" ~/.local/share/applications/qtile-*.desktop 2>/dev/null || true
    sed -i "s|Exec=~/|Exec=$HOME/|g" ~/.local/share/applications/show-keys.desktop 2>/dev/null || true
    sed -i "s|Exec=~/|Exec=$HOME/|g" ~/.local/share/applications/idle-settings.desktop 2>/dev/null || true
    
    if is_laptop; then
        cp "$CONFIG_DIR/qtile/qtile-touchpad-setup" ~/.local/bin/qtile-touchpad-setup
        chmod +x ~/.local/bin/qtile-touchpad-setup
        cp "$CONFIG_DIR/qtile/qtile-touchpad-setup.desktop" ~/.local/share/applications/qtile-touchpad-setup.desktop
    fi

    cp "$CONFIG_DIR/qtile/qtile-audio-setup" ~/.local/bin/qtile-audio-setup
    chmod +x ~/.local/bin/qtile-audio-setup
    chmod +x ~/.config/qtile/autostart.sh


    
    sudo mkdir -p /usr/share/xsessions
    sudo tee /usr/share/xsessions/qtile.desktop > /dev/null << EOF
[Desktop Entry]
Name=Qtile
Comment=Qtile Session
Exec=qtile start
Type=Application
Keywords=wm;tiling
EOF

    # El paquete oficial 'qtile' de Arch registra también una sesión Wayland
    # (/usr/share/wayland-sessions/qtile-wayland.desktop) que SDDM prioriza sobre X11
    # cuando no hay preferencia previa del usuario. Este flujo no instala las dependencias
    # del backend Wayland de Qtile (python-wlroots/python-xkbcommon) — Hyprland ya cubre
    # Wayland en este repo. Se elimina para evitar login loop (exit code 11 al intentar
    # 'qtile start -b wayland').
    sudo rm -f /usr/share/wayland-sessions/qtile-wayland.desktop

    ok "Configuraciones copiadas y sesión SDDM creada."
}

# ─── Touchpad (libinput, X11) ─────────────────────────────────────────────────
install_touchpad() {
    step "Configurando touchpad (libinput)..."

    paru_install xorg-xinput

    local conf="/etc/X11/xorg.conf.d/40-libinput.conf"
    if [[ -f "$conf" ]] && grep -q "Tapping" "$conf" 2>/dev/null; then
        ok "Touchpad ya configurado"
        return
    fi

    sudo mkdir -p /etc/X11/xorg.conf.d
    sudo tee "$conf" > /dev/null << 'EOF'
Section "InputClass"
    Identifier "libinput touchpad"
    MatchIsTouchpad "on"
    Driver "libinput"
    Option "Tapping" "on"
    Option "NaturalScrolling" "true"
    Option "DisableWhileTyping" "true"
EndSection
EOF
    ok "Touchpad configurado (tap-to-click, scroll natural, disable-while-typing)"
}

# ─── Ahorro de Energía (Laptop) y Safe Eyes (Descansos) ────────────────────────
install_power_breaks() {
    # 1. Safe Eyes (Descansos en laptop y desktop)
    step "Instalando Safe Eyes para descansos obligatorios..."
    paru_install safeeyes
    ok "Safe Eyes instalado."

    # 2. TLP (Ahorro de batería) - Solo en Laptops
    if is_laptop; then
        step "Laptop detectada: Instalando TLP y TLPUI para ahorro de batería..."
        paru_install tlp tlpui
        sudo systemctl enable --now tlp.service
        ok "TLP instalado y servicio tlp.service habilitado."
    else
        ok "Desktop detectado: Omitiendo la instalación de TLP."
    fi
}

# ─── MAIN ─────────────────────────────────────────────────────────────────────
setup_aur
select_file_manager
menu_optional
show_summary
install_base
install_optional_packages
install_applets
install_audio
install_theme_system
install_eww
install_idle
install_sddm
configure_grub
copy_configs
    is_laptop && install_touchpad
    install_kb_switch
    install_power_breaks

echo -e "\n${BOLD}${GREEN}¡Instalación de Qtile-Omarchy (X11) completada con éxito!${NC}"
echo -e "Puedes reiniciar el equipo o cerrar sesión, y seleccionar 'Qtile' en SDDM.\n"
