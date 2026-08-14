#!/bin/bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ install-hyprland-desktop.sh                                                 │
# │ Personalización del escritorio Hyprland: waybar, rofi, temas, audio        │
# │                                                                             │
# │ Requiere instalación base completada con install-cachyos-hyprland.sh        │
# └─────────────────────────────────────────────────────────────────────────────┘

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install-hyprland-desktop.log"

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

configure_mirrors() {
    [[ "${SKIP_SYSTEM_UPDATE:-0}" == "1" ]] && { ok "Mirrors — omitido (ejecutado desde install-completo.sh)"; return; }
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
    [[ "${SKIP_SYSTEM_UPDATE:-0}" == "1" ]] && { ok "Actualización — omitida (ejecutado desde install-completo.sh)"; return; }
    step "Actualizando el sistema..."
    ensure_pacman_unlocked
    sudo pacman -Syu --noconfirm \
        || die "Falló la actualización del sistema — verifica mirrors y conexión"
    ok "Sistema actualizado"
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

# ─── paru con retry de red ────────────────────────────────────────────────────
# Uso: paru_install [--warn] pkg1 [pkg2 ...]
#   Sin --warn: fallo es fatal (die). Con --warn: fallo es advertencia (warn).
paru_install() {
    local critical=true
    [[ "${1:-}" == "--warn" ]] && { critical=false; shift; }
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

    local attempt=0 max_retries=3
    local tmplog
    tmplog=$(mktemp /tmp/paru_install.XXXXXX)

    while (( attempt < max_retries )); do
        (( attempt++ ))
        : > "$tmplog"

        if paru -S --needed --noconfirm "${to_install[@]}" 2>&1 | tee "$tmplog"; then
            ok "${to_install[*]} instalado"
            rm -f "$tmplog"
            return 0
        fi

        if grep -qiE "could not resolve|failed to retrieve|network is unreachable|curl: \([67]\)|temporary failure" "$tmplog" \
                && (( attempt < max_retries )); then
            warn "Error de red en intento $attempt/$max_retries para ${to_install[*]} — refrescando mirrors..."
            echo "$(date '+%Y-%m-%d %H:%M:%S') [intento $attempt/$max_retries] RED: ${to_install[*]}" >> "$LOG_FILE"
            cachyos-rate-mirrors &>/dev/null || warn "cachyos-rate-mirrors falló — continuando con mirrors actuales"
            sleep 5
            info "Reintentando ${to_install[*]}..."
            continue
        fi

        break
    done

    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S') FALLO tras $attempt intento(s): ${to_install[*]} ==="
        cat "$tmplog"
        echo ""
    } >> "$LOG_FILE"
    rm -f "$tmplog"

    # Reintentar paquete a paquete antes de fallar
    warn "Reintentando paquete a paquete..."
    local failed=()
    for pkg in "${to_install[@]}"; do
        pacman -Qq "$pkg" &>/dev/null && continue
        if ! paru -S --needed --noconfirm --skipreview "$pkg"; then
            warn "$pkg no se pudo instalar — continuando"
            failed+=("$pkg")
        fi
    done

    rm -f "$tmplog"

    if [[ ${#failed[@]} -eq 0 ]]; then
        ok "Todos los paquetes instalados en reintento individual"
        return 0
    fi

    if $critical; then
        die "Paquetes críticos no instalados: ${failed[*]} — ver $LOG_FILE"
    else
        warn "Paquetes no instalados: ${failed[*]} — ver $LOG_FILE"
        return 1
    fi
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

# ─── Detección de hardware ────────────────────────────────────────────────────
# Devuelve 0 (true) si el chassis DMI indica dispositivo portátil.
# Tipos portátiles: 8=Portable 9=Laptop 10=Notebook 11=HandHeld
#                   14=SubNotebook 31=Convertible 32=Detachable
# Fallback: presencia de batería (cubre VMs y hardware sin DMI correcto).
is_laptop() {
    local chassis
    chassis=$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)
    case "$chassis" in
        8|9|10|11|14|31|32) return 0 ;;
    esac
    ls /sys/class/power_supply/BAT* &>/dev/null
}

# Devuelve 0 (true) si el fabricante del primer adaptador de video contiene "Intel"
is_intel_gpu() {
    lspci | grep -Ei "VGA|3D|Display" | grep -qi intel
}

# ─── Prerequisitos ────────────────────────────────────────────────────────────
check_prereqs() {
    step "Verificando prerequisitos (install-cachyos-hyprland.sh requerido)..."
    ensure_pacman_unlocked

    local missing=()

    # Binarios críticos
    command -v hyprctl   >/dev/null || missing+=("hyprland")
    command -v waybar    >/dev/null || missing+=("waybar")
    command -v rofi      >/dev/null || missing+=("rofi-wayland")
    command -v paru      >/dev/null || missing+=("paru")
    command -v mako      >/dev/null || missing+=("mako")
    command -v cliphist  >/dev/null || missing+=("cliphist")
    command -v uwsm      >/dev/null || missing+=("uwsm")
    command -v swaybg    >/dev/null || missing+=("swaybg")
    command -v hypridle   >/dev/null || missing+=("hypridle")
    command -v hyprlock   >/dev/null || missing+=("hyprlock")
    command -v hyprsunset >/dev/null || missing+=("hyprsunset")
    command -v eww        >/dev/null || missing+=("eww")
    command -v sass       >/dev/null || missing+=("dart-sass")

    # Paquetes (no dejan binario en PATH pero son críticos)
    pacman -Q sddm          &>/dev/null || missing+=("sddm")
    pacman -Q wl-clipboard  &>/dev/null || missing+=("wl-clipboard")
    pacman -Q polkit-gnome  &>/dev/null || missing+=("polkit-gnome")

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        warn "Paquetes faltantes detectados: ${missing[*]}"
        info "Instalando automáticamente paquetes faltantes con paru..."
        paru -S --needed --noconfirm "${missing[@]}" || die "No se pudieron instalar los paquetes faltantes."
    fi

    ok "Prerequisitos satisfechos — install-cachyos-hyprland.sh completado"
}

# ─── Inicialización del config de Hyprland ────────────────────────────────────
init_hyprland_config() {
    step "Verificando config de Hyprland..."

    # PATH de la sesión gráfica: uwsm sourcea ~/.config/uwsm/env al iniciar.
    # Sin esto ~/.local/bin queda fuera del PATH y los binds que llaman scripts
    # de ahí (theme-switcher, etc.) fallan con "command not found" silencioso.
    local uwsm_env="$HOME/.config/uwsm/env"
    mkdir -p "$HOME/.config/uwsm"
    if grep -q 'HOME/.local/bin' "$uwsm_env" 2>/dev/null; then
        ok "PATH de sesión (~/.local/bin) ya configurado en uwsm/env"
    else
        printf '%s\n' '# Agrega ~/.local/bin al PATH de la sesión gráfica (sourced por uwsm)' \
                      'export PATH="$HOME/.local/bin:$PATH"' >> "$uwsm_env"
        ok "PATH de sesión agregado a $uwsm_env"
    fi

    local lua="$HOME/.config/hypr/hyprland.lua"
    local conf="$HOME/.config/hypr/hyprland.conf"
    local default_lua="/usr/share/hypr/hyprland.lua"

    # Eliminar stub autogenerado — si existe y tiene autogenerated=1, Hyprland
    # lo usaría en lugar del lua, ignorando toda la configuración real
    if [[ -f "$conf" ]] && grep -q 'autogenerated\s*=\s*1' "$conf"; then
        mv "$conf" "${conf}.stub"
        ok "hyprland.conf stub movido a hyprland.conf.stub"
    fi

    # Crear directorio y .lua desde la plantilla del sistema si no existen
    mkdir -p "$HOME/.config/hypr"
    if [[ ! -f "$lua" ]]; then
        [[ -f "$default_lua" ]] || die "Plantilla $default_lua no encontrada — verifica la instalación de Hyprland"
        cp "$default_lua" "$lua"
        ok "hyprland.lua inicializado desde $default_lua"
    else
        ok "hyprland.lua existente ($(wc -l < "$lua") líneas)"
    fi

    # Ajuste visual: gaps_out 10 (default 20 es excesivo en pantallas medianas)
    sed -i 's/gaps_out\s*=\s*[0-9]\+/gaps_out = 10/' "$lua"
    ok "gaps_out ajustado a 10"

    # Configurar teclado en hyprland.lua basado en la configuración del sistema (vconsole/X11)
    detect_keyboard_layout
    sed -i "s/kb_layout\s*=\s*\".*\"/kb_layout  = \"$SYS_KB_LAYOUT\"/" "$lua"
    sed -i "s/kb_variant\s*=\s*\".*\"/kb_variant = \"$SYS_KB_VARIANT\"/" "$lua"
    ok "Teclado en hyprland.lua configurado a: layout=$SYS_KB_LAYOUT, variant=$SYS_KB_VARIANT"

    # SIEMPRE garantizar bloque autostart funcional (idempotente)
    # El default de Hyprland trae el bloque comentado → nunca queda activo sin este paso
    if grep -q 'exec_cmd("uwsm app -- waybar")' "$lua" 2>/dev/null; then
        ok "autostart waybar ya activo en hyprland.lua"
    else
        # Usar $HOME explícito para que funcione tanto con sudo como sin él
        python3 - "$lua" << 'PYEOF'
import sys, os

lua_path = sys.argv[1]

with open(lua_path) as f:
    lines = f.readlines()

new_block = (
    'hl.on("hyprland.start", function()\n'
    '    hl.exec_cmd("uwsm app -- waybar")\n'
    '    hl.exec_cmd("uwsm app -- hypridle")\n'
    '    hl.exec_cmd("uwsm app -- swaybg -m fill -i ~/.config/omarchy/current/background")\n'
    '    hl.exec_cmd("dbus-update-activation-environment --systemd --all")\n'
    '    hl.exec_cmd("systemctl --user import-environment $(env | cut -d= -f 1)")\n'
    'end)\n\n'
)

# Caso 1: existe bloque comentado — reemplazarlo
start_idx = end_idx = None
for i, line in enumerate(lines):
    if '-- hl.on("hyprland.start"' in line or "-- hl.on('hyprland.start'" in line:
        start_idx = i
    if start_idx is not None and '-- end)' in line and i > start_idx:
        end_idx = i
        break

if start_idx is not None and end_idx is not None:
    lines = lines[:start_idx] + [new_block] + lines[end_idx+1:]
    print('   bloque autostart descomentado y activado')
else:
    # Caso 2 (defensivo): sin bloque comentado — insertar tras la última hl.env()
    insert_after = None
    for i, line in enumerate(lines):
        if 'hl.env(' in line:
            insert_after = i
    if insert_after is not None:
        lines.insert(insert_after + 1, '\n' + new_block)
        print('   bloque autostart insertado tras último hl.env()')
    else:
        lines.append('\n' + new_block)
        print('   bloque autostart añadido al final')

with open(lua_path, 'w') as f:
    f.writelines(lines)
PYEOF
    fi
}

# ─── Fuentes Nerd Font ────────────────────────────────────────────────────────
install_fonts() {
    step "Instalando fuentes Nerd Font..."
    if pacman -Q ttf-jetbrains-mono-nerd &>/dev/null; then
        ok "ttf-jetbrains-mono-nerd ya instalada"
    else
        pacman_install ttf-jetbrains-mono-nerd
        ok "ttf-jetbrains-mono-nerd instalada"
    fi
    fc-cache -f
    ok "Caché de fuentes actualizado"
}

# ─── Waybar ───────────────────────────────────────────────────────────────────
install_waybar() {
    step "Configurando waybar..."
    mkdir -p ~/.config/waybar

    cat > ~/.config/waybar/config.jsonc << 'WAYBAR_CONFIG'
{
  "reload_style_on_change": true,
  "layer": "top",
  "position": "top",
  "spacing": 0,
  "height": 26,
  "width": 0,
  "modules-left": ["custom/launcher", "hyprland/workspaces"],
  "modules-center": ["clock"],
  "modules-right": [
    "bluetooth",
    "pulseaudio",
    "backlight",
    "cpu",
    "battery",
    "tray"
  ],

  "hyprland/workspaces": {
    "on-click": "activate",
    "format": "{icon}",
    "format-icons": {
      "default": "",
      "1": "1",
      "2": "2",
      "3": "3",
      "4": "4",
      "5": "5",
      "6": "6",
      "7": "7",
      "8": "8",
      "9": "9",
      "10": "0",
      "active": "󱓻"
    },
    "persistent-workspaces": {
      "1": [],
      "2": [],
      "3": [],
      "4": [],
      "5": []
    }
  },

  "custom/launcher": {
    "format": "󰣇",
    "on-click": "uwsm app -- rofi -show drun",
    "on-click-right": "uwsm app -- alacritty",
    "tooltip-format": "Lanzador  Super+Space\nTerminal  Clic derecho"
  },

  "clock": {
    "format": "{:L%A %H:%M}",
    "format-alt": "{:L%d %B W%V %Y}",
    "tooltip": false
  },

  "cpu": {
    "interval": 5,
    "format": "󰍛",
    "on-click": "uwsm app -- alacritty -e btop",
    "tooltip-format": "CPU {usage}%"
  },

  "battery": {
    "format-discharging": "{icon}",
    "format-charging": "{icon}",
    "format-plugged": "",
    "format-full": "󰂅",
    "format-icons": {
      "charging": ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"],
      "default": ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
    },
    "tooltip-format-discharging": "{power:>1.0f}W  {capacity}%",
    "tooltip-format-charging": "{power:>1.0f}W  {capacity}%",
    "interval": 5,
    "states": {
      "warning": 20,
      "critical": 10
    }
  },

  "bluetooth": {
    "format": "",
    "format-off": "󰂲",
    "format-disabled": "󰂲",
    "format-connected": "󰂱",
    "format-no-controller": "",
    "tooltip-format": "Dispositivos conectados: {num_connections}",
    "on-click": "uwsm app -- blueman-manager"
  },

  "pulseaudio": {
    "format": "{icon}",
    "on-click": "uwsm app -- pavucontrol",
    "on-click-right": "pamixer -t",
    "tooltip-format": "Volumen: {volume}%",
    "scroll-step": 5,
    "format-muted": "󰖁",
    "format-icons": {
      "headphone": "󰋋",
      "headset": "󰋎",
      "default": ["󰕿", "󰖀", "󰕾"]
    }
  },

  "backlight": {
    "device": "intel_backlight",
    "format": "{icon}",
    "format-icons": ["󰃞", "󰃟", "󰃠"],
    "scroll-step": 5,
    "tooltip-format": "Brillo: {percent}%"
  },

  "tray": {
    "icon-size": 12,
    "spacing": 17
  }
}
WAYBAR_CONFIG

    ok "config.jsonc instalado"

    cat > ~/.config/waybar/style.css << WAYBAR_STYLE
@import "$HOME/.config/omarchy/current/waybar-colors.css";

* {
  background-color: @background;
  color: @foreground;
  border: none;
  border-radius: 0;
  min-height: 0;
  font-family: 'JetBrainsMono Nerd Font';
  font-size: 12px;
}

.modules-left  { margin-left:  8px; }
.modules-right { margin-right: 8px; }

#custom-launcher {
  font-size: 16px;
  color: @accent;
  margin: 0 10px 0 4px;
  padding: 0 4px;
}

#custom-launcher:hover {
  color: @foreground;
}

#workspaces button {
  all: initial;
  color: @foreground;
  padding: 0 6px;
  margin: 0 1.5px;
  min-width: 9px;
}

#workspaces button.empty   { opacity: 0.4; }
#workspaces button.active  { color: @accent; }
#workspaces button:hover   { color: @foreground; }

#clock {
  margin: 0 8.75px;
}

#cpu,
#battery,
#pulseaudio,
#bluetooth {
  min-width: 12px;
  margin: 0 7.5px;
}

#battery.warning  { color: @warning; }
#battery.critical { color: @critical; }

#tray { margin-right: 8px; }

#backlight {
  min-width: 12px;
  margin: 0 7.5px;
}

tooltip {
  padding: 2px;
  background-color: @surface;
  color: @foreground;
}
WAYBAR_STYLE

    ok "style.css instalado (theming dinámico vía omarchy)"

    step "Instalando herramientas GUI de audio y bluetooth..."
    pacman_install pavucontrol blueman
    ok "pavucontrol y blueman instalados"

    step "Recargando waybar..."
    pkill -x waybar 2>/dev/null || true; sleep 0.3 && (uwsm app -- waybar >/dev/null 2>&1 &)
    ok "waybar reiniciado"
}

# ─── NetworkManager Applet ────────────────────────────────────────────────────
install_nm_applet() {
    step "Instalando network-manager-applet..."
    if pacman -Q network-manager-applet &>/dev/null; then
        ok "network-manager-applet ya instalado"
    else
        pacman_install network-manager-applet
        ok "network-manager-applet instalado"
    fi

    local lua="$HOME/.config/hypr/hyprland.lua"
    if [[ ! -f "$lua" ]]; then
        warn "No se encontró $lua — agrega manualmente: hl.exec_cmd(\"uwsm app -- nm-applet --indicator\")"
        return
    fi

    if grep -q "nm-applet" "$lua"; then
        ok "nm-applet ya está en el autostart de hyprland.lua"
    else
        sed -i 's|hl.exec_cmd("uwsm app -- hypridle")|hl.exec_cmd("uwsm app -- hypridle")\n    hl.exec_cmd("uwsm app -- nm-applet --indicator")|' "$lua"
        ok "nm-applet agregado al autostart de hyprland.lua"
    fi

    uwsm app -- nm-applet --indicator &
    ok "nm-applet iniciado"
}

# ─── Audio ────────────────────────────────────────────────────────────────────
install_audio() {
    step "Instalando soporte de audio..."

    # sof-firmware — firmware para DSP de audio Intel (Tiger Lake, Alder Lake, etc.)
    # Solo necesario en plataformas Intel; en AMD el audio lo gestiona directamente ALSA/PipeWire
    if is_intel_gpu; then
        if pacman -Q sof-firmware &>/dev/null; then
            ok "sof-firmware ya instalado"
        else
            pacman_install sof-firmware
            warn "sof-firmware instalado — se requiere reinicio para activar el hardware de audio"
        fi
    else
        info "sof-firmware omitido — no aplica en GPU no-Intel"
    fi

    if pacman -Q pipewire-pulse &>/dev/null; then
        ok "pipewire-pulse ya instalado"
    else
        pacman_install pipewire-pulse
        ok "pipewire-pulse instalado"
    fi

    if pacman -Q pamixer &>/dev/null; then
        ok "pamixer ya instalado"
    else
        pacman_install pamixer
        ok "pamixer instalado"
    fi

    # Activar pipewire-pulse como servicio de usuario
    if systemctl --user enable --now pipewire-pulse.service 2>/dev/null; then
        ok "pipewire-pulse.service activo"
    else
        warn "pipewire-pulse.service: actívalo manualmente tras iniciar sesión gráfica"
    fi
}

# ─── SwayOSD (indicador visual de volumen y brillo) ──────────────────────────
install_swayosd() {
    step "Instalando swayosd..."
    if pacman -Q swayosd &>/dev/null; then
        ok "swayosd ya instalado"
    else
        pacman_install swayosd
        ok "swayosd instalado"
    fi

    local lua="$HOME/.config/hypr/hyprland.lua"
    if [[ ! -f "$lua" ]]; then
        warn "No se encontró $lua — configura swayosd manualmente"
        return
    fi

    # Agregar swayosd-server al autostart
    if grep -q "swayosd-server" "$lua"; then
        ok "swayosd-server ya está en el autostart"
    else
        sed -i 's|hl.exec_cmd("uwsm app -- nm-applet --indicator")|hl.exec_cmd("uwsm app -- nm-applet --indicator")\n    hl.exec_cmd("uwsm app -- swayosd-server")|' "$lua"
        ok "swayosd-server agregado al autostart"
    fi

    # Reemplazar bindings de volumen wpctl por swayosd-client (idempotente)
    if grep -q "swayosd-client" "$lua"; then
        ok "Bindings de swayosd-client ya configurados"
    else
        sed -i 's|wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+|swayosd-client --output-volume raise|g' "$lua"
        sed -i 's|wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-|swayosd-client --output-volume lower|g'     "$lua"
        sed -i 's|wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle|swayosd-client --output-volume mute-toggle|g' "$lua"
        ok "Bindings de volumen actualizados a swayosd-client"
    fi

    # Reemplazar bindings de brillo brightnessctl por swayosd-client (idempotente)
    if grep -q 'swayosd-client --brightness' "$lua"; then
        ok "Bindings de brillo con swayosd-client ya configurados"
    else
        sed -i 's|hl.dsp.exec_cmd("brightnessctl.*set 5%+")|hl.dsp.exec_cmd("swayosd-client --brightness raise")|g' "$lua"
        sed -i 's|hl.dsp.exec_cmd("brightnessctl.*set 5%-")|hl.dsp.exec_cmd("swayosd-client --brightness lower")|g' "$lua"
        ok "Bindings de brillo actualizados a swayosd-client"
    fi

    uwsm app -- swayosd-server &
    ok "swayosd-server iniciado"
}

# ─── Bluetooth ────────────────────────────────────────────────────────────────
install_bluetooth() {
    step "Configurando Bluetooth..."

    local lua="$HOME/.config/hypr/hyprland.lua"

    for pkg in bluez blueman; do
        paru_install "$pkg"
    done

    sudo systemctl enable --now bluetooth.service
    ok "bluetooth.service activo"

    if grep -q "blueman-applet" "$lua" 2>/dev/null; then
        ok "blueman-applet ya en autostart"
    else
        sed -i 's|hl.exec_cmd("uwsm app -- nm-applet --indicator")|hl.exec_cmd("uwsm app -- nm-applet --indicator")\n    hl.exec_cmd("uwsm app -- blueman-applet")|' "$lua"
        ok "blueman-applet añadido al autostart"
    fi

    ok "Bluetooth listo — Super+Ctrl+B abre blueman-manager"
}

# ─── Polkit (agente de autenticación gráfico) ────────────────────────────────
install_polkit() {
    step "Configurando agente polkit..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    local agent="/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"

    paru_install polkit-gnome

    if grep -q "polkit-gnome" "$lua" 2>/dev/null; then
        ok "polkit-gnome ya en autostart"
    else
        sed -i "s|hl.exec_cmd(\"uwsm app -- nm-applet --indicator\")|hl.exec_cmd(\"uwsm app -- nm-applet --indicator\")\n    hl.exec_cmd(\"uwsm app -- ${agent}\")|" "$lua"
        ok "polkit-gnome añadido al autostart"
    fi

    # polkit-agent-helper-1 necesita SUID para leer /etc/shadow al autenticar
    local helper="/usr/lib/polkit-1/polkit-agent-helper-1"
    if [[ "$(stat -c %a "$helper" 2>/dev/null)" != "4755" ]]; then
        sudo chmod 4755 "$helper"
        ok "SUID aplicado a polkit-agent-helper-1"
    else
        ok "polkit-agent-helper-1 ya tiene SUID"
    fi

    # Regla polkit udisks2: miembros del grupo sudo montan sin contraseña
    # YES en lugar de AUTH_SELF_KEEP porque lectores internos (microSD) son
    # clasificados como HintSystem=true y requerirían auth_admin por defecto
    local rules_dir="/etc/polkit-1/rules.d"
    if [[ ! -f "$rules_dir/50-udisks2.rules" ]]; then
        sudo tee "$rules_dir/50-udisks2.rules" > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.udisks2") === 0 &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
EOF
        ok "Regla polkit udisks2 creada"
    else
        ok "Regla polkit udisks2 ya existe"
    fi
    sudo systemctl restart polkit

    # Wrapper para RPi Imager en Wayland
    # pkexec no preserva WAYLAND_DISPLAY/XDG_RUNTIME_DIR → proceso root no puede
    # conectar al socket Wayland del usuario. Solución: sudo con env_keep en
    # sudoers.d, sin contraseña para este binario específico.
    local sudoers_file="/etc/sudoers.d/rpi-imager"
    if [[ ! -f "$sudoers_file" ]]; then
        local tmp
        tmp=$(mktemp)
        cat > "$tmp" << EOF
Defaults!/usr/bin/rpi-imager env_keep += "WAYLAND_DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS"
${USER} ALL=(root) NOPASSWD: /usr/bin/rpi-imager
EOF
        sudo visudo -c -f "$tmp" && sudo cp "$tmp" "$sudoers_file" && sudo chmod 0440 "$sudoers_file"
        rm -f "$tmp"
        ok "Sudoers rpi-imager instalado"
    else
        ok "Sudoers rpi-imager ya existe"
    fi

    local wrapper="$HOME/.local/bin/rpi-imager-wayland"
    if [[ ! -f "$wrapper" ]]; then
        cat > "$wrapper" << 'SCRIPT_EOF'
#!/usr/bin/env bash
exec sudo /usr/bin/rpi-imager
SCRIPT_EOF
        chmod +x "$wrapper"

        mkdir -p "$HOME/.local/share/applications"
        cat > "$HOME/.local/share/applications/com.raspberrypi.rpi-imager.desktop" << EOF
[Desktop Entry]
Type=Application
Version=1.5
Name=Raspberry Pi Imager
Comment=Tool for writing images to SD cards for Raspberry Pi
Icon=rpi-imager
Exec=${wrapper} %u
Categories=Utility;
StartupNotify=false
MimeType=x-scheme-handler/rpi-imager;application/vnd.raspberrypi.imager-manifest+json;
EOF
        ok "Wrapper rpi-imager-wayland instalado"
    else
        ok "Wrapper rpi-imager-wayland ya existe"
    fi
}

# ─── udiskie (automontaje USB) ────────────────────────────────────────────────
install_udiskie() {
    step "Configurando udiskie (automontaje USB)..."

    local lua="$HOME/.config/hypr/hyprland.lua"

    paru_install udiskie

    if grep -q "udiskie" "$lua" 2>/dev/null; then
        ok "udiskie ya en autostart"
    else
        sed -i 's|hl.exec_cmd("uwsm app -- blueman-applet")|hl.exec_cmd("uwsm app -- blueman-applet")\n    hl.exec_cmd("uwsm app -- udiskie --tray")|' "$lua"
        ok "udiskie añadido al autostart"
    fi
}

# ─── XDG Desktop Portal ───────────────────────────────────────────────────────
install_xdg_portal() {
    step "Configurando XDG Desktop Portal..."

    local lua="$HOME/.config/hypr/hyprland.lua"

    paru_install xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk

    # dbus-update-activation-environment exporta WAYLAND_DISPLAY y XDG_CURRENT_DESKTOP
    # al entorno D-Bus del usuario, necesario para que el portal detecte Hyprland
    if grep -q "dbus-update-activation-environment" "$lua" 2>/dev/null; then
        ok "dbus-update-activation-environment ya en hyprland.lua"
    else
        cat >> "$lua" <<'EOF'
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
EOF
        ok "dbus-update-activation-environment añadido a hyprland.lua"
    fi

    if grep -q "import-environment" "$lua" 2>/dev/null; then
        ok "systemctl --user import-environment ya en hyprland.lua"
    else
        cat >> "$lua" <<'EOF'
    hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
EOF
        ok "import-environment añadido a hyprland.lua"
    fi
}

# ─── Touchpad ─────────────────────────────────────────────────────────────────
install_touchpad() {
    step "Configurando touchpad..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    [[ -f "$lua" ]] || { warn "No se encontró $lua"; return; }

    if grep -q "tap_to_click" "$lua"; then
        ok "Touchpad ya configurado"
        return
    fi

    sed -i 's|touchpad = {|touchpad = {\n            disable_while_typing = true,\n            tap_to_click         = true,|' "$lua"
    ok "tap_to_click y disable_while_typing activados"
}

# ─── Switcher de teclado (US intl / Latam / España) ──────────────────────────
install_kb_switch() {
    step "Instalando kb-switch..."

    sudo tee /usr/local/bin/kb-switch > /dev/null << 'EOF'
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
    sudo chmod +x /usr/local/bin/kb-switch
    ok "kb-switch instalado en /usr/local/bin/"
}

# ─── Alacritty (terminal local con tema Catppuccin) ───────────────────────────
install_alacritty() {
    step "Instalando Alacritty..."

    if pacman -Q alacritty &>/dev/null; then
        ok "alacritty ya instalado"
    else
        pacman_install alacritty
        ok "alacritty instalado"
    fi

    # Crear estructura de config
    mkdir -p "$HOME/.config/alacritty/themes"

    # Descargar tema Catppuccin Mocha
    local tema="$HOME/.config/alacritty/themes/catppuccin-mocha.toml"
    if [[ -f "$tema" ]]; then
        ok "tema catppuccin-mocha ya descargado"
    else
        curl -sLo "$tema" \
            "https://raw.githubusercontent.com/catppuccin/alacritty/main/catppuccin-mocha.toml"
        ok "tema catppuccin-mocha descargado"
    fi

    # Escribir alacritty.toml
    local cfg="$HOME/.config/alacritty/alacritty.toml"
    cat > "$cfg" << 'TOML'
[general]
import = [
    "~/.config/alacritty/themes/catppuccin-mocha.toml",
    "~/.config/omarchy/current/alacritty-colors.toml",
]

[window]
decorations = "none"
opacity = 0.95
padding = { x = 8, y = 8 }

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold   = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size   = 13.0

[cursor]
style = { shape = "Block", blinking = "On" }

[scrolling]
history = 10000
TOML
    ok "alacritty.toml actualizado"

    # Actualizar hyprland.lua: cambiar terminal de foot a alacritty
    local lua="$HOME/.config/hypr/hyprland.lua"
    if [[ ! -f "$lua" ]]; then
        warn "No se encontró $lua — edita manualmente: local terminal = \"alacritty\""
        return
    fi

    if grep -q 'local terminal.*=.*"alacritty"' "$lua"; then
        ok "hyprland.lua ya usa alacritty como terminal"
    else
        sed -i 's|^local terminal\s*=.*|local terminal    = "alacritty"|' "$lua"
        ok "hyprland.lua actualizado: terminal = alacritty"
    fi

    # fileManager y menu — el default usa dolphin/hyprlauncher, se corrigen aquí
    local fm_binary="nautilus"
    if command -v thunar &>/dev/null; then
        fm_binary="thunar"
    fi
    if grep -q "local fileManager.*=.*\"$fm_binary\"" "$lua"; then
        ok "hyprland.lua ya usa $fm_binary como fileManager"
    else
        sed -i "s|^local fileManager\s*=.*|local fileManager = \"$fm_binary\"|" "$lua"
        ok "hyprland.lua actualizado: fileManager = $fm_binary"
    fi

    # menu DEBE incluir -show drun; sin él rofi abre vacío (nada seleccionable)
    if grep -q 'local menu.*=.*"rofi -show drun"' "$lua"; then
        ok "hyprland.lua ya usa rofi -show drun como menu"
    else
        sed -i 's|^local menu\s*=.*|local menu        = "rofi -show drun"|' "$lua"
        ok "hyprland.lua actualizado: menu = rofi -show drun"
    fi
}


# ─── hyprsunset (filtro de luz azul) ──────────────────────────────────────────
install_hyprsunset() {
    step "Configurando hyprsunset..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    if [[ ! -f "$lua" ]]; then
        warn "No se encontró $lua — agrega manualmente al autostart: hyprsunset -t 4500"
        return
    fi

    if grep -q "hyprsunset" "$lua"; then
        ok "hyprsunset ya está en el autostart"
    else
        sed -i 's|hl.exec_cmd("uwsm app -- swayosd-server")|hl.exec_cmd("uwsm app -- swayosd-server")\n    hl.exec_cmd("uwsm app -- hyprsunset -t 4500")|' "$lua"
        ok "hyprsunset agregado al autostart (4500K)"
    fi
}

# ─── hyprlock + hypridle (pantalla de bloqueo) ────────────────────────────────
install_hyprlock() {
    step "Configurando hyprlock e hypridle..."

    local lua="$HOME/.config/hypr/hyprland.lua"

    # hypridle.conf
    local idle_conf="$HOME/.config/hypr/hypridle.conf"
    if [[ ! -f "$idle_conf" ]]; then
        cat > "$idle_conf" << 'EOF'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = hyprlock
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = hyprlock
}

listener {
    timeout = 600
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 1800
    on-timeout = systemctl suspend
}
EOF
        ok "hypridle.conf creado"
    else
        ok "hypridle.conf ya existe"
    fi

    # hyprlock.conf
    local lock_conf="$HOME/.config/hypr/hyprlock.conf"
    if [[ ! -f "$lock_conf" ]]; then
        cat > "$lock_conf" << 'EOF'
source = ~/.config/omarchy/current/hyprlock-colors.conf

general {
    disable_loading_bar = true
    hide_cursor = true
    grace = 0
}

background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 7
}

input-field {
    monitor =
    size = 300, 50
    outline_thickness = 2
    dots_size = 0.2
    dots_spacing = 0.2
    outer_color = $outer_color
    inner_color = $inner_color
    font_color = $font_color
    fade_on_empty = true
    placeholder_text = <i>Contraseña...</i>
    rounding = 8
    position = 0, -100
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "<b>$(date +'%H:%M')</b>"
    color = $font_color
    font_size = 72
    font_family = JetBrainsMono Nerd Font
    position = 0, 300
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:60000] echo "<b>$(date +'%A, %d de %B')</b>"
    color = rgba(166, 173, 200, 1.0)
    font_size = 18
    font_family = JetBrainsMono Nerd Font
    position = 0, 200
    halign = center
    valign = center
}
EOF
        ok "hyprlock.conf creado"
    else
        ok "hyprlock.conf ya existe"
    fi

    # Keybinding Super+Ctrl+L
    if [[ -f "$lua" ]]; then
        if grep -q "hyprlock" "$lua"; then
            ok "Keybinding Super+Ctrl+L ya existe en hyprland.lua"
        else
            sed -i '/exec_cmd(menu)/a hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))' "$lua"
            ok "Keybinding Super+Ctrl+L agregado en hyprland.lua"
        fi
    else
        warn "No se encontró $lua — agrega manualmente: hl.bind(mainMod .. \" + CTRL + L\", hl.dsp.exec_cmd(\"hyprlock\"))"
    fi
}

# ─── Conky (monitor del sistema en el escritorio) ─────────────────────────────
install_eww() {
    step "Instalando eww (monitor del sistema Wayland)..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    local apps_dir="$HOME/.local/share/applications"
    local bin="$HOME/.local/bin"
    mkdir -p "$apps_dir" "$bin" ~/.config/eww

    # Paquetes
    pacman_install intel-gpu-tools
    ok "intel-gpu-tools instalado"

    paru_install eww

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
  :geometry (geometry :x "45px" :y "50px" :width "255px" :anchor "top right")
  :stacking "bottom"
  :exclusive false
  :focusable false
  (sysmon))
YUCKEOF
    ok "~/.config/eww/eww.yuck creado"

    # ── eww.scss (Catppuccin Mocha) ───────────────────────────────────────────
    cat > ~/.config/eww/eww.scss << 'SCSSEOF'
$base:     rgba(30, 30, 46, 0.82);
$surface0: #313244;
$surface1: #45475a;
$text:     #cdd6f4;
$subtext:  #a6adc8;
$mauve:    #cba6f7;
$sky:      #89dceb;

* { font-family: "JetBrainsMono Nerd Font"; font-size: 9pt; }

.sysmon {
  background-color: $base;
  padding: 10px 12px;
  border-radius: 10px;
  color: $text;
}

.clock {
  color: $mauve;
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

.section { color: $sky; font-weight: bold; margin-top: 2px; }

.srow { margin: 1px 0; }
.key  { color: $subtext; min-width: 52px; }
.val  { color: $text; }

.sbar {
  margin: 2px 0 4px;
  trough {
    background-color: $surface1;
    border-radius: 3px;
    min-height: 5px;
  }
  highlight, progress {
    background-color: $sky;
    border-radius: 3px;
    min-height: 5px;
  }
  slider {
    min-width: 0; min-height: 0;
    background: none; border: none; box-shadow: none;
  }
}
SCSSEOF
    ok "~/.config/eww/eww.scss creado"

    # ── Autostart en hyprland.lua ─────────────────────────────────────────────
    # Eliminar restos de conky si los hay
    sed -i '/exec_cmd.*conky/d' "$lua"
    sed -i '/exec_cmd.*hyprctl keyword windowrulev2.*conky/d' "$lua"
    sed -i '/-- Conky/,/})/{ /-- Conky/d; /conky-desktop/d; /class.*[Cc]onky/d; /float.*true/{ /pin\|below/d }; /^$/{ /-- Conky/,/})/d } }' "$lua" 2>/dev/null || true

    if grep -q 'exec_cmd.*eww' "$lua" 2>/dev/null; then
        ok "eww ya en autostart"
    else
        sed -i 's|hl.exec_cmd("uwsm app -- nm-applet --indicator")|hl.exec_cmd("uwsm app -- nm-applet --indicator")\n    hl.exec_cmd("eww open sysmon")|' "$lua"
        ok "eww añadido al autostart"
    fi

    # ── .desktop ──────────────────────────────────────────────────────────────
    cat > "$apps_dir/eww-sysmon.desktop" << 'EOF'
[Desktop Entry]
Name=EWW Monitor
Comment=Monitor del sistema (widget Wayland)
Exec=eww open sysmon
Icon=utilities-system-monitor
Type=Application
Categories=System;Monitor;
NoDisplay=false
EOF
    ok "eww-sysmon.desktop creado"
}

# ─── Pantalla y suspensión (idle-settings) ────────────────────────────────────
install_idle_settings() {
    step "Configurando idle-settings..."

    sudo tee /usr/local/bin/idle-settings > /dev/null << 'SCRIPT'
#!/bin/bash
# idle-settings — configura tiempos de inactividad y energía vía rofi
# Flujo: Bloquear pantalla → Acción de energía (Suspender / Hibernar / Ninguna) → Tiempo

CONF="$HOME/.config/hypr/hypridle.conf"

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

# Leer valores actuales del conf para mostrarlos en los menús
lock_cur=$(awk '/hyprlock/{f=1} f && /timeout/{print $3; exit}' "$CONF" 2>/dev/null)
action_cur="Ninguna"
grep -q 'systemctl suspend'   "$CONF" 2>/dev/null && action_cur="Suspender"
grep -q 'systemctl hibernate' "$CONF" 2>/dev/null && action_cur="Hibernar"
action_time_cur=$(grep -B2 'systemctl' "$CONF" 2>/dev/null | awk '/timeout/{print $3}' | tail -1)
lock_min=$(( ${lock_cur:-300} / 60 ))
action_min=$(( ${action_time_cur:-1800} / 60 ))

# 1) Tiempo de bloqueo de pantalla
lock_choice=$(rofi_pick "Bloquear pantalla  [actual: ${lock_min} min]")
[[ -z "$lock_choice" ]] && exit 0
lock_sec=$(to_seconds "$lock_choice")
[[ $lock_sec -eq -1 ]] && exit 1

# 2) Acción de energía
action_choice=$(rofi_action "Acción de energía  [actual: ${action_cur}]")
[[ -z "$action_choice" ]] && exit 0

# 3) Tiempo de la acción (solo si no es Ninguna)
action_sec=0
action_time_choice=""
if [[ "$action_choice" != "Ninguna" ]]; then
    action_time_choice=$(rofi_pick "${action_choice}  [actual: ${action_min} min]")
    [[ -z "$action_time_choice" ]] && exit 0
    action_sec=$(to_seconds "$action_time_choice")
    [[ $action_sec -eq -1 ]] && exit 1

    if [[ $lock_sec -gt 0 && $action_sec -gt 0 && $action_sec -le $lock_sec ]]; then
        notify-send "Pantalla y energía" \
            "El tiempo de ${action_choice,,} debe ser mayor al de bloqueo." --urgency=critical
        exit 1
    fi
fi

# DPMS: apaga pantalla 5 min después del bloqueo, si cabe antes de la acción de energía
dpms_sec=0
if [[ $lock_sec -gt 0 ]]; then
    candidate=$(( lock_sec + 300 ))
    if [[ $action_sec -eq 0 || $candidate -lt $action_sec ]]; then
        dpms_sec=$candidate
    fi
fi

# Comando de energía
action_cmd=""
[[ "$action_choice" == "Suspender" ]] && action_cmd="systemctl suspend"
[[ "$action_choice" == "Hibernar"  ]] && action_cmd="systemctl hibernate"

{
cat << 'HEADER'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = hyprlock
    after_sleep_cmd = hyprctl dispatch dpms on
}
HEADER

[[ $lock_sec -gt 0 ]] && cat << BLOCK

listener {
    timeout = $lock_sec
    on-timeout = hyprlock
}
BLOCK

[[ $dpms_sec -gt 0 ]] && cat << BLOCK

listener {
    timeout = $dpms_sec
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}
BLOCK

[[ $action_sec -gt 0 && -n "$action_cmd" ]] && cat << BLOCK

listener {
    timeout = $action_sec
    on-timeout = $action_cmd
}
BLOCK
} > "$CONF"

pkill -x hypridle 2>/dev/null; sleep 0.3; uwsm app -- hypridle &

msg="Bloqueo: ${lock_choice}"
[[ "$action_choice" != "Ninguna" ]] && msg="${msg}\n${action_choice}: ${action_time_choice}"
notify-send "Pantalla y energía" "$msg" --icon=system-lock-screen
SCRIPT
    sudo chmod +x /usr/local/bin/idle-settings
    ok "idle-settings instalado en /usr/local/bin/"

    local apps_dir="$HOME/.local/share/applications"
    mkdir -p "$apps_dir"
    cat > "$apps_dir/idle-settings.desktop" << 'EOF'
[Desktop Entry]
Name=Pantalla y energía
Comment=Configura el bloqueo de pantalla, la suspensión y la hibernación automáticas
Exec=idle-settings
Icon=preferences-system-privacy-screen
Type=Application
Categories=Settings;
NoDisplay=false
EOF
    ok "idle-settings.desktop creado en ~/.local/share/applications/"
}

# ─── wiremix (mixer TUI PipeWire) ─────────────────────────────────────────────
install_wiremix() {
    step "Configurando wiremix..."

    local lua="$HOME/.config/hypr/hyprland.lua"

    if ! pacman -Q wiremix &>/dev/null; then
        warn "wiremix no instalado — ejecuta: paru -S wiremix"
        return
    fi

    if [[ -f "$lua" ]] && grep -q "wiremix" "$lua"; then
        ok "Keybinding Super+Ctrl+A (wiremix) ya existe"
    elif [[ -f "$lua" ]]; then
        sed -i '/exec_cmd("hyprlock")/a hl.bind(mainMod .. " + CTRL + A", hl.dsp.exec_cmd("alacritty -e wiremix"))' "$lua"
        ok "Keybinding Super+Ctrl+A (wiremix) agregado"
    else
        warn "No se encontró $lua — agrega manualmente: hl.bind(mainMod .. \" + CTRL + A\", hl.dsp.exec_cmd(\"alacritty -e wiremix\"))"
    fi
}

# ─── Cliphist (historial de portapapeles) ─────────────────────────────────────
install_cliphist() {
    step "Configurando cliphist (historial de portapapeles)..."

    local lua="$HOME/.config/hypr/hyprland.lua"

    if ! pacman -Q cliphist &>/dev/null || ! pacman -Q wl-clipboard &>/dev/null; then
        warn "cliphist o wl-clipboard no instalados — ejecuta: paru -S cliphist wl-clipboard"
        return
    fi

    if [[ -f "$lua" ]] && grep -q "cliphist store" "$lua"; then
        ok "Daemon cliphist en autostart ya existe"
    elif [[ -f "$lua" ]]; then
        python3 -c "
path = '$lua'
with open(path) as f:
    c = f.read()
target = 'hl.exec_cmd(\"uwsm app -- hypridle\")'
repl = target + '\n    hl.exec_cmd(\"wl-paste --type text --watch cliphist store\")'
if 'cliphist store' not in c and target in c:
    with open(path, 'w') as f:
        f.write(c.replace(target, repl, 1))
    print('OK')
"
        ok "Daemon cliphist agregado al autostart"
    else
        warn "No se encontró $lua — agrega manualmente en autostart: wl-paste --type text --watch cliphist store"
    fi

    if [[ -f "$lua" ]] && grep -q "cliphist list" "$lua"; then
        ok "Keybinding Super+Ctrl+V (cliphist) ya existe"
    elif [[ -f "$lua" ]]; then
        python3 -c "
path = '$lua'
with open(path) as f:
    c = f.read()
target = 'hl.bind(mainMod .. \" + CTRL + A\", hl.dsp.exec_cmd(\"alacritty -e wiremix\"))'
repl = target + \"\nhl.bind(mainMod .. \\\" + CTRL + V\\\", hl.dsp.exec_cmd(\\\"bash -c 'cliphist list | rofi -dmenu -p Portapapeles | cliphist decode | wl-copy'\\\"))\"
if 'cliphist list' not in c and target in c:
    with open(path, 'w') as f:
        f.write(c.replace(target, repl, 1))
    print('OK')
"
        ok "Keybinding Super+Ctrl+V (cliphist) agregado"
    else
        warn "No se encontró $lua — agrega manualmente: Super+Ctrl+V → cliphist list | rofi -dmenu | cliphist decode | wl-copy"
    fi
}

# ─── Wallpaper (tema catppuccin Omarchy) ─────────────────────────────────────
install_wallpaper() {
    step "Configurando wallpaper (Omarchy catppuccin)..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    local bg_dir="$HOME/.local/share/backgrounds"
    local bg_file="$bg_dir/omarchy-catppuccin-2-waves.png"
    local bg_url="https://raw.githubusercontent.com/basecamp/omarchy/dev/themes/catppuccin/backgrounds/2-waves.png"

    mkdir -p "$bg_dir"

    if [[ -f "$bg_file" ]]; then
        ok "Wallpaper ya descargado"
    else
        curl -sL "$bg_url" -o "$bg_file"
        ok "Wallpaper descargado"
    fi

    if [[ -f "$lua" ]]; then
        # Reemplazar swaybg hardcodeado por theme-apply para usar siempre el tema activo
        if grep -q "theme-apply" "$lua"; then
            ok "Autostart theme-apply ya configurado en hyprland.lua"
        elif grep -q "swaybg" "$lua"; then
            sed -i 's|swaybg -m fill -i [^"]*|~/.local/bin/theme-apply|' "$lua"
            ok "swaybg reemplazado por theme-apply en autostart"
        else
            warn "No se encontró swaybg en $lua — agrega theme-apply al autostart manualmente"
        fi

        # Desactivar logo, splash y wallpaper por defecto de Hyprland
        if grep -q "disable_hyprland_logo   = true" "$lua"; then
            ok "disable_hyprland_logo ya es true"
        else
            sed -i 's/disable_hyprland_logo   = false/disable_hyprland_logo   = true/' "$lua"
            ok "disable_hyprland_logo establecido en true"
        fi
        if grep -q "disable_splash_rendering" "$lua"; then
            ok "disable_splash_rendering ya presente"
        else
            sed -i 's/disable_hyprland_logo   = true/disable_hyprland_logo   = true,\n        disable_splash_rendering = true/' "$lua"
            ok "disable_splash_rendering agregado"
        fi
        if grep -q "force_default_wallpaper = 0" "$lua"; then
            ok "force_default_wallpaper ya es 0"
        else
            sed -i 's/force_default_wallpaper = -1/force_default_wallpaper = 0/' "$lua"
            ok "force_default_wallpaper establecido en 0"
        fi
    else
        warn "No se encontró $lua — configura theme-apply en autostart manualmente"
    fi

    # Aplicar en vivo si hay sesión Wayland (theme-apply aún no existe; se aplica wallpaper de fallback)
    if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v swaybg &>/dev/null; then
        pkill -x swaybg 2>/dev/null
        setsid swaybg -i "$bg_file" -m fill >/dev/null 2>&1 &
        ok "Wallpaper catppuccin aplicado en sesión activa (theme-apply se aplicará tras reinicio)"
    fi
}

# ─── Aplicaciones del escritorio ──────────────────────────────────────────────
install_apps() {
    step "Configurando aplicaciones del escritorio..."

    # Verificar instalación (paru requiere usuario — solo advertir si faltan)
    local missing=()
    for pkg in imv mpv signal-desktop obsidian typora drawio-desktop; do
        pacman -Q "$pkg" &>/dev/null || missing+=("$pkg")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        warn "Paquetes no instalados: ${missing[*]}"
        warn "Instalar con: paru -S ${missing[*]}"
    fi

    # xdg defaults — imv para imágenes (mpv se establece solo al instalarse)
    if pacman -Q imv &>/dev/null; then
        for mime in image/jpeg image/png image/gif image/webp image/svg+xml image/bmp image/tiff; do
            xdg-mime default imv.desktop "$mime"
        done
        ok "imv establecido como visor de imágenes por defecto"
    fi
}

# ─── Sistema de temas Nivel 1 (consistencia visual) ───────────────────────────
install_theme() {
    step "Configurando sistema de temas Catppuccin Mocha..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    paru_install catppuccin-gtk-theme-mocha catppuccin-cursors-mocha papirus-icon-theme nwg-look kvantum kvantum-qt5

    # gsettings GTK
    gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-mauve-standard+default'
    gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
    gsettings set org.gnome.desktop.interface cursor-theme 'catppuccin-mocha-dark-cursors'
    gsettings set org.gnome.desktop.interface cursor-size 24
    ok "gsettings aplicados"

    # GTK settings.ini
    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    for dir in gtk-3.0 gtk-4.0; do
        cat > "$HOME/.config/$dir/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=catppuccin-mocha-mauve-standard+default
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=catppuccin-mocha-dark-cursors
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
EOF
    done
    ok "GTK settings.ini creados"

    # XCURSOR_THEME en hyprland.lua
    if [[ -f "$lua" ]]; then
        if grep -q "XCURSOR_THEME" "$lua"; then
            ok "XCURSOR_THEME ya definido en hyprland.lua"
        else
            sed -i 's|hl.env("XCURSOR_SIZE", "24")|hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")\n    hl.env("XCURSOR_SIZE", "24")|' "$lua"
            sed -i 's/^    hl\.env("XCURSOR_SIZE"/hl.env("XCURSOR_SIZE"/' "$lua"
            ok "XCURSOR_THEME agregado a hyprland.lua"
        fi
    fi

    # Kvantum
    mkdir -p "$HOME/.config/Kvantum"
    if [[ ! -f "$HOME/.config/Kvantum/kvantum.kvconfig" ]]; then
        cat > "$HOME/.config/Kvantum/kvantum.kvconfig" << 'EOF'
[General]
theme=KvDark
EOF
        ok "Kvantum configurado con tema KvDark"
    else
        ok "Kvantum ya configurado"
    fi
}

# ─── Mako (notificaciones Catppuccin Mocha) ───────────────────────────────────
install_mako() {
    step "Configurando mako (Catppuccin Mocha)..."
    mkdir -p "$HOME/.config/mako"
    local cfg="$HOME/.config/mako/config"
    if grep -q "background-color=#1e1e2e" "$cfg" 2>/dev/null; then
        ok "mako ya configurado con Catppuccin Mocha"
        return
    fi
    cat > "$cfg" << 'MAKO_EOF'
font=JetBrainsMono Nerd Font 12
background-color=#1e1e2e
text-color=#cdd6f4
border-color=#cba6f7
progress-color=over #313244
border-size=2
border-radius=8
default-timeout=5000
ignore-timeout=0
sort=-time
layer=overlay
width=300
margin=10
padding=15
max-visible=5

[urgency=high]
border-color=#f38ba8
default-timeout=0
MAKO_EOF
    makoctl reload 2>/dev/null || true
    ok "mako configurado con Catppuccin Mocha"
}

# ─── Rofi (lanzador Catppuccin Mocha) ─────────────────────────────────────────
install_rofi() {
    step "Configurando rofi (tema unificado omarchy)..."
    # El tema de rofi lo genera theme-apply en ~/.config/omarchy/current/rofi.rasi,
    # siguiendo el tema activo del sistema (ver install_theme_switcher / rofi.rasi.tpl).
    # Aquí solo se escribe el config base con ruta ABSOLUTA al tema generado.
    mkdir -p "$HOME/.config/rofi" "$HOME/.config/omarchy/current"

    local cfg="$HOME/.config/rofi/config.rasi"
    local theme_dst="$HOME/.config/omarchy/current/rofi.rasi"

    if grep -qF "@theme \"$theme_dst\"" "$cfg" 2>/dev/null; then
        ok "rofi ya integrado al tema unificado"
        return
    fi

    cat > "$cfg" << 'ROFI_CFG_EOF'
configuration {
    modi:        "drun,run,window";
    show-icons:  true;
    icon-theme:  "Papirus-Dark";
    drun-display-format: "{name}";
    font:        "JetBrainsMono Nerd Font 12";
}
ROFI_CFG_EOF
    # Ruta absoluta (rofi bajo uwsm no siempre expande ~ de forma fiable)
    printf '\n@theme "%s"\n' "$theme_dst" >> "$cfg"

    ok "rofi configurado para seguir el tema unificado (theme-apply genera $theme_dst)"
}

# ─── Bindings estilo Omarchy ──────────────────────────────────────────────────
install_omarchy_bindings() {
    step "Configurando bindings estilo Omarchy..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    if [[ ! -f "$lua" ]]; then
        warn "No se encontró $lua — agrega bindings manualmente"
        return
    fi

    python3 << 'PYEOF'
import sys, os

lua_path = os.path.expanduser('~/.config/hypr/hyprland.lua')
with open(lua_path, 'r') as f:
    content = f.read()

# Renombres (idempotentes — solo aplican si el string viejo existe)
renames = [
    ('" + C", hl.dsp.window.close()',                     '" + SHIFT + W", hl.dsp.window.close()'),
    ('" + V", hl.dsp.window.float({ action = "toggle" })','" + T", hl.dsp.window.float({ action = "toggle" })'),
    ('" + R", hl.dsp.exec_cmd(menu)',                     '" + SPACE", hl.dsp.exec_cmd(menu)'),
    ('" + L", hl.dsp.exec_cmd("hyprlock")',               '" + CTRL + L", hl.dsp.exec_cmd("hyprlock")'),
    ('" + A", hl.dsp.exec_cmd("alacritty -e wiremix")',   '" + CTRL + A", hl.dsp.exec_cmd("alacritty -e wiremix")'),
]
for old, new in renames:
    if old in content:
        content = content.replace(old, new)

# Nuevos bindings — insertar una sola vez tras el último XF86
if 'Pantalla completa (Omarchy)' not in content:
    import shutil
    fm_cmd = "thunar" if shutil.which("thunar") else "nautilus"
    anchor = 'hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })'
    new_blocks = f'''

-- Pantalla completa (Omarchy)
hl.bind(mainMod .. " + F",                     hl.dsp.window.fullscreen({{ mode = "fullscreen" }}))
hl.bind(mainMod .. " + ALT + F",               hl.dsp.window.fullscreen({{ mode = "maximized" }}))

-- Navegación de workspaces por teclado (Omarchy)
hl.bind(mainMod .. " + TAB",                   hl.dsp.focus({{ workspace = "e+1" }}))
hl.bind(mainMod .. " + SHIFT + TAB",           hl.dsp.focus({{ workspace = "e-1" }}))
hl.bind(mainMod .. " + CTRL + TAB",            hl.dsp.focus({{ workspace = "previous" }}))

-- Ciclo de ventanas (Omarchy)
hl.bind("ALT + TAB",                           hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + TAB",                   hl.dsp.window.cycle_next({{ next = false }}))

-- Grupos de ventanas (Omarchy)
hl.bind(mainMod .. " + G",                     hl.dsp.group.toggle())
hl.bind(mainMod .. " + ALT + TAB",             hl.dsp.group.next())
hl.bind(mainMod .. " + ALT + SHIFT + TAB",     hl.dsp.group.prev())

-- Herramientas del sistema (Omarchy)
hl.bind(mainMod .. " + E",                     hl.dsp.exec_cmd("uwsm app -- {fm_cmd}"))
hl.bind(mainMod .. " + CTRL + B",              hl.dsp.exec_cmd("blueman-manager"))
hl.bind(mainMod .. " + CTRL + W",              hl.dsp.exec_cmd("alacritty -e nmtui"))
hl.bind(mainMod .. " + CTRL + T",              hl.dsp.exec_cmd("alacritty -e btop"))
hl.bind(mainMod .. " + SHIFT + SPACE",         hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))

-- Notificaciones mako (Omarchy)
hl.bind(mainMod .. " + COMMA",                 hl.dsp.exec_cmd("makoctl dismiss"))
hl.bind(mainMod .. " + SHIFT + COMMA",         hl.dsp.exec_cmd("makoctl dismiss --all"))'''
    if anchor in content:
        content = content.replace(anchor, anchor + new_blocks)
    else:
        print('AVISO: anchor XF86AudioPrev no encontrado — verifica manualmente')

# Super+E — Gestor de archivos (idempotente — para installs existentes sin este binding)
import shutil
fm_cmd = "thunar" if shutil.which("thunar") else "nautilus"
if f'hl.dsp.exec_cmd("uwsm app -- {fm_cmd}")' not in content:
    # Remover versión anterior si existe
    old_cmd = "nautilus" if fm_cmd == "thunar" else "thunar"
    content = content.replace(f'hl.bind(mainMod .. " + E",                     hl.dsp.exec_cmd("uwsm app -- {old_cmd}"))\n', "")
    
    anchor_e = 'hl.bind(mainMod .. " + CTRL + B"'
    if anchor_e in content:
        content = content.replace(anchor_e,
            f'hl.bind(mainMod .. " + E",                     hl.dsp.exec_cmd("uwsm app -- {fm_cmd}"))\n' + anchor_e, 1)
    else:
        print('AVISO: no se encontró anchor para Super+E — agrega manualmente')

# Super+K — kb-switch (idempotente — para installs existentes sin este binding)
if 'hl.dsp.exec_cmd("kb-switch")' not in content:
    anchor_k = 'hl.bind(mainMod .. " + CTRL + B"'
    if anchor_k in content:
        content = content.replace(anchor_k,
            'hl.bind(mainMod .. " + K",                     hl.dsp.exec_cmd("kb-switch"))\n' + anchor_k, 1)
    else:
        print('AVISO: no se encontró anchor para Super+K — agrega manualmente')

with open(lua_path, 'w') as f:
    f.write(content)

print('LISTO')
PYEOF

    ok "Bindings Omarchy configurados en hyprland.lua"
}

# ─── Sistema de temas Omarchy (21 temas, theme-apply + theme-switcher) ────────
install_theme_switcher() {
    step "Instalando sistema de temas Omarchy (21 temas)..."

    local themes_dir="$HOME/.config/omarchy/themes"
    local current_dir="$HOME/.config/omarchy/current"
    local tpl_dir="$HOME/.local/share/omarchy-local/themed"
    local bg_dir="$HOME/.local/share/backgrounds"
    local bin_dir="$HOME/.local/bin"
    local clone_dir="/tmp/omarchy-themes-$$"

    mkdir -p "$themes_dir" "$current_dir" "$tpl_dir" "$bg_dir" "$bin_dir"

    for pkg in catppuccin-gtk-theme-latte catppuccin-cursors-latte; do
        paru_install "$pkg"
    done

    # ── Templates ──────────────────────────────────────────────────────────────
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

    cat > "$tpl_dir/waybar-colors.css.tpl" << 'TPL_EOF'
@define-color foreground {{ foreground }};
@define-color background {{ mantle }};
@define-color surface    {{ background }};
@define-color accent     {{ accent }};
@define-color warning    {{ color1 }};
@define-color critical   {{ color1 }};
TPL_EOF

    cat > "$tpl_dir/hyprland-colors.lua.tpl" << 'TPL_EOF'
hl.config({
    general = {
        col = {
            active_border   = "rgba({{ accent_strip }}ee)",
            inactive_border = "rgba({{ color0_strip }}aa)",
        }
    },
    group = {
        col = {
            border_active        = "rgba({{ accent_strip }}ee)",
            border_inactive      = "rgba({{ color0_strip }}aa)",
            border_locked_active = "rgba({{ accent_strip }}ee)",
        }
    }
})
TPL_EOF

    cat > "$tpl_dir/hyprlock-colors.conf.tpl" << 'TPL_EOF'
$outer_color = rgb({{ accent_strip }})
$inner_color = rgb({{ background_strip }})
$font_color  = rgb({{ foreground_strip }})
$check_color = rgb({{ color2_strip }})
TPL_EOF

    cat > "$tpl_dir/mako-colors.ini.tpl" << 'TPL_EOF'
background-color={{ background }}
text-color={{ foreground }}
border-color={{ accent }}
TPL_EOF

    # Template de rofi: el launcher sigue el tema activo (integrado a theme-apply)
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

    ok "Templates instalados en $tpl_dir"

    # ── Script theme-apply ─────────────────────────────────────────────────────
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
    -e "s|{{ accent_strip }}|${accent_strip}|g"
    -e "s|{{ background_strip }}|${background_strip}|g"
    -e "s|{{ foreground_strip }}|${foreground_strip}|g"
    -e "s|{{ color0_strip }}|${color0_strip}|g"
    -e "s|{{ color2_strip }}|${color2_strip}|g"
)

sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/alacritty-colors.toml.tpl" > "${CURRENT_DIR}/alacritty-colors.toml"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/waybar-colors.css.tpl"     > "${CURRENT_DIR}/waybar-colors.css"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/hyprland-colors.lua.tpl"   > "${CURRENT_DIR}/hyprland-colors.lua"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/hyprlock-colors.conf.tpl"  > "${CURRENT_DIR}/hyprlock-colors.conf"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/mako-colors.ini.tpl"       > "${CURRENT_DIR}/mako-colors.ini"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/rofi.rasi.tpl"             > "${CURRENT_DIR}/rofi.rasi"
sed "${SED_ARGS[@]}" "${TEMPLATES_DIR}/eww.scss.tpl"              > "${HOME}/.config/eww/eww.scss"

MAKO_CFG="${HOME}/.config/mako/config"
sed -i "s|^background-color=.*|background-color=${background}|" "$MAKO_CFG"
sed -i "s|^text-color=.*|text-color=${foreground}|"             "$MAKO_CFG"
sed -i "0,/^border-color=.*/s|^border-color=.*|border-color=${accent}|" "$MAKO_CFG"

# GTK (campos opcionales en colors.toml; gsettings no requiere WAYLAND_DISPLAY)
gtk_theme_field=$(_opt gtk_theme)
color_scheme_field=$(_opt color_scheme)
cursor_theme_field=$(_opt cursor_theme)
icon_theme_field=$(_opt icon_theme)

if [[ -n "${gtk_theme_field:-}" ]]; then
    gsettings set org.gnome.desktop.interface gtk-theme    "$gtk_theme_field" 2>/dev/null || true
    [[ -n "${color_scheme_field:-}" ]] && gsettings set org.gnome.desktop.interface color-scheme  "$color_scheme_field" 2>/dev/null || true
    [[ -n "${cursor_theme_field:-}" ]] && gsettings set org.gnome.desktop.interface cursor-theme  "$cursor_theme_field" 2>/dev/null || true
    [[ -n "${icon_theme_field:-}" ]]   && gsettings set org.gnome.desktop.interface icon-theme    "$icon_theme_field"   2>/dev/null || true

    prefer_dark_int=1
    [[ "${color_scheme_field:-prefer-dark}" == "prefer-light" ]] && prefer_dark_int=0
    for _d in "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"; do
        [[ -f "$_d/settings.ini" ]] || continue
        sed -i "s|^gtk-theme-name=.*|gtk-theme-name=${gtk_theme_field}|" "$_d/settings.ini"
        sed -i "s|^gtk-application-prefer-dark-theme=.*|gtk-application-prefer-dark-theme=${prefer_dark_int}|" "$_d/settings.ini"
        [[ -n "${cursor_theme_field:-}" ]] && sed -i "s|^gtk-cursor-theme-name=.*|gtk-cursor-theme-name=${cursor_theme_field}|" "$_d/settings.ini"
        [[ -n "${icon_theme_field:-}" ]]   && sed -i "s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=${icon_theme_field}|"     "$_d/settings.ini"
    done
fi

HYPR_SIG=$(ls "/run/user/$(id -u)/hypr/" 2>/dev/null | tail -1)
if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    if pgrep -x waybar >/dev/null 2>&1; then
        pkill waybar 2>/dev/null || true
        sleep 0.5
        nohup waybar >/dev/null 2>&1 &
    fi
    if pgrep -x eww >/dev/null 2>&1; then
        eww reload 2>/dev/null || true
    else
        nohup eww open sysmon >/dev/null 2>&1 &
    fi
    [[ -n "${HYPR_SIG:-}" ]] && HYPRLAND_INSTANCE_SIGNATURE="$HYPR_SIG" hyprctl reload
fi

pgrep -x mako >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]] && makoctl reload 2>/dev/null || true

[[ -n "${wallpaper:-}" ]] && echo "$wallpaper" > "${CURRENT_DIR}/background"

if [[ -n "${wallpaper:-}" && -f "$wallpaper" && -n "${WAYLAND_DISPLAY:-}" ]]; then
    pkill swaybg 2>/dev/null || true
    nohup swaybg -i "$wallpaper" -m fill >/dev/null 2>&1 &
fi

# GRUB: sincronizar tema en background (efectivo en próximo reboot)
_grub_map="${HOME}/.local/share/omarchy-local/grub-theme-map"
if [[ -f "$_grub_map" ]]; then
    _grub_theme=$(grep "^${THEME}=" "$_grub_map" 2>/dev/null | cut -d= -f2)
    [[ -z "$_grub_theme" ]] && _grub_theme=$(grep "^default=" "$_grub_map" | cut -d= -f2)
    _grub_path="/usr/share/grub/themes/${_grub_theme}/theme.txt"
    [[ -f "$_grub_path" ]] && sudo /usr/local/bin/grub-apply-theme "$_grub_path" >/dev/null 2>&1 &
fi

echo "$THEME" > "${CURRENT_DIR}/theme"
echo "Tema '${THEME}' aplicado."
APPLY_EOF
    chmod +x "$bin_dir/theme-apply"
    ok "theme-apply instalado"

    # ── Script theme-switcher ──────────────────────────────────────────────────
    cat > "$bin_dir/theme-switcher" << 'SWITCHER_EOF'
#!/usr/bin/env bash
set -euo pipefail

THEMES_DIR="${HOME}/.config/omarchy/themes"

TEMA=$(ls "$THEMES_DIR" | rofi -dmenu -p "Tema" -i -theme-str 'window {width: 300px;}')
[[ -z "$TEMA" ]] && exit 0

"${HOME}/.local/bin/theme-apply" "$TEMA"
SWITCHER_EOF
    chmod +x "$bin_dir/theme-switcher"
    ok "theme-switcher instalado"

    # ── Wallpapers y colors.toml: sparse-checkout del repo Omarchy ────────────
    if ! command -v git &>/dev/null; then
        warn "git no disponible — instala git y re-ejecuta para bajar wallpapers"
    else
        rm -rf "$clone_dir"
        git clone --depth=1 --filter=blob:none --sparse \
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

    # ── Binding Super+Shift+T → theme-switcher ─────────────────────────────────
    local lua="$HOME/.config/hypr/hyprland.lua"
    if [[ -f "$lua" ]]; then
        python3 << 'PYEOF'
import os

lua_path = os.path.expanduser('~/.config/hypr/hyprland.lua')
with open(lua_path, 'r') as f:
    content = f.read()

marker = 'Selector de tema (Omarchy)'
if marker not in content:
    anchor = 'hl.bind(mainMod .. " + SHIFT + SPACE"'
    insert = '\n-- Selector de tema (Omarchy)\nhl.bind(mainMod .. " + SHIFT + T",          hl.dsp.exec_cmd("theme-switcher"))\n\n'
    if anchor in content:
        content = content.replace(anchor, insert + anchor)
    else:
        content += '\n-- Selector de tema (Omarchy)\nhl.bind(mainMod .. " + SHIFT + T",          hl.dsp.exec_cmd("theme-switcher"))\n'

with open(lua_path, 'w') as f:
    f.write(content)

print('LISTO')
PYEOF
        ok "Binding Super+Shift+T configurado"
    else
        warn "No se encontró $lua — agrega el binding manualmente"
    fi

    # ── PATH: asegurar ~/.local/bin disponible ────────────────────────────────
    if grep -q "^export PATH=.*local/bin" "$HOME/.zshrc" 2>/dev/null; then
        ok "~/.local/bin ya en PATH en .zshrc"
    elif grep -q "^# export PATH=.*local/bin" "$HOME/.zshrc" 2>/dev/null; then
        sed -i 's|^# export PATH=\$HOME/bin:\$HOME/.local/bin|export PATH=$HOME/bin:$HOME/.local/bin|' "$HOME/.zshrc"
        ok "~/.local/bin añadido al PATH en .zshrc (línea descomentada)"
    else
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        ok "~/.local/bin añadido al PATH en .zshrc (línea añadida)"
    fi

    # ── Aplicar tema nord por defecto ─────────────────────────────────────────
    # theme-apply genera los archivos CSS/config sin necesitar display;
    # si falla swaybg por falta de Wayland, los archivos de tema quedan listos igual.
    if [[ -f "$themes_dir/nord/colors.toml" && -f "$bin_dir/theme-apply" ]]; then
        "$bin_dir/theme-apply" nord 2>/dev/null \
            && ok "Tema nord aplicado — archivos de tema generados" \
            || { echo "nord" > "$current_dir/theme"
                 warn "theme-apply falló (¿sin Wayland?) — tema registrado, regenerar con: theme-apply nord"; }
    fi
}

# ─── DNS local: systemd-resolved + avahi ─────────────────────────────────────
install_dns() {
    step "Configurando DNS local (systemd-resolved + avahi)..."

    # ── Paquetes ────────────────────────────────────────────────────────────────
    for pkg in avahi nss-mdns; do
        paru_install "$pkg"
    done

    # ── NetworkManager → systemd-resolved ──────────────────────────────────────
    if grep -q "dns=systemd-resolved" /etc/NetworkManager/conf.d/dns.conf 2>/dev/null; then
        ok "NetworkManager ya delegando DNS a systemd-resolved"
    else
        sudo mkdir -p /etc/NetworkManager/conf.d
        printf '[main]\ndns=systemd-resolved\n' | sudo tee /etc/NetworkManager/conf.d/dns.conf > /dev/null
        ok "NetworkManager configurado para usar systemd-resolved"
    fi

    # ── Servicios ───────────────────────────────────────────────────────────────
    for svc in systemd-resolved avahi-daemon; do
        if systemctl is-active "$svc" &>/dev/null; then
            ok "$svc ya activo"
        else
            sudo systemctl enable --now "$svc"
            ok "$svc habilitado y activo"
        fi
    done

    # ── resolv.conf → stub de systemd-resolved ─────────────────────────────────
    if grep -q "127.0.0.53" /etc/resolv.conf 2>/dev/null; then
        ok "resolv.conf ya apunta a systemd-resolved"
    else
        sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        ok "resolv.conf enlazado a stub de systemd-resolved"
    fi

    # ── nsswitch.conf: añadir mdns_minimal ────────────────────────────────────
    if grep -q "mdns_minimal" /etc/nsswitch.conf; then
        ok "nsswitch.conf ya tiene mdns_minimal"
    else
        sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' /etc/nsswitch.conf
        ok "nsswitch.conf actualizado con mdns_minimal"
    fi

    # ── Reiniciar NetworkManager ────────────────────────────────────────────────
    sudo systemctl restart NetworkManager
    ok "NetworkManager reiniciado"

    # ── Verificación ────────────────────────────────────────────────────────────
    local hostname
    hostname=$(cat /etc/hostname)
    if avahi-resolve --name "${hostname}.local" &>/dev/null; then
        ok "${hostname}.local resuelve correctamente via avahi"
    else
        warn "avahi-resolve falló — puede necesitar unos segundos para anunciarse"
    fi
}

# ─── Screenshots (grim + slurp + satty) ──────────────────────────────────────
install_screenshots() {
    step "Instalando capturas de pantalla (grim + slurp + satty)..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    local bin_dir="$HOME/.local/bin"
    local ss_dir="$HOME/Pictures/Screenshots"

    # ── Paquetes ────────────────────────────────────────────────────────────────
    for pkg in grim slurp satty jq; do
        paru_install "$pkg"
    done

    mkdir -p "$ss_dir" "$bin_dir"
    ok "Directorio ~/Pictures/Screenshots listo"

    # ── screenshot-area: selección de área → satty ─────────────────────────────
    if [[ ! -f "$bin_dir/screenshot-area" ]]; then
        cat > "$bin_dir/screenshot-area" << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
SS_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SS_DIR"
FILENAME="$SS_DIR/$(date +%Y%m%d_%H%M%S).png"
grim -g "$(slurp)" - | satty --filename - --output-filename "$FILENAME"
SCRIPT_EOF
        chmod +x "$bin_dir/screenshot-area"
        ok "screenshot-area instalado"
    else
        ok "screenshot-area ya existe"
    fi

    # ── screenshot-full: pantalla completa → satty ─────────────────────────────
    if [[ ! -f "$bin_dir/screenshot-full" ]]; then
        cat > "$bin_dir/screenshot-full" << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
SS_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SS_DIR"
FILENAME="$SS_DIR/$(date +%Y%m%d_%H%M%S).png"
grim - | satty --filename - --output-filename "$FILENAME"
SCRIPT_EOF
        chmod +x "$bin_dir/screenshot-full"
        ok "screenshot-full instalado"
    else
        ok "screenshot-full ya existe"
    fi

    # ── screenshot-window: ventana activa → satty ──────────────────────────────
    if [[ ! -f "$bin_dir/screenshot-window" ]]; then
        cat > "$bin_dir/screenshot-window" << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
SS_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SS_DIR"
FILENAME="$SS_DIR/$(date +%Y%m%d_%H%M%S).png"
GEOM=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
grim -g "$GEOM" - | satty --filename - --output-filename "$FILENAME"
SCRIPT_EOF
        chmod +x "$bin_dir/screenshot-window"
        ok "screenshot-window instalado"
    else
        ok "screenshot-window ya existe"
    fi

    # ── screenshot-copy: selección de área → portapapeles directo ─────────────
    if [[ ! -f "$bin_dir/screenshot-copy" ]]; then
        cat > "$bin_dir/screenshot-copy" << 'SCRIPT_EOF'
#!/usr/bin/env bash
set -euo pipefail
grim -g "$(slurp)" - | wl-copy
notify-send "Screenshot" "Captura copiada al portapapeles" -t 2000
SCRIPT_EOF
        chmod +x "$bin_dir/screenshot-copy"
        ok "screenshot-copy instalado"
    else
        ok "screenshot-copy ya existe"
    fi

    # ── Bindings en hyprland.lua ───────────────────────────────────────────────
    if [[ -f "$lua" ]]; then
        python3 << 'PYEOF'
import sys, os
lua_path = os.path.expanduser('~/.config/hypr/hyprland.lua')
with open(lua_path) as f:
    content = f.read()

if 'screenshot-area' in content:
    print('SKIP')
    sys.exit(0)

bin = os.path.expanduser('~/.local/bin')
block = (
    '\n-- Capturas de pantalla (grim + slurp + satty)\n'
    f'hl.bind("Print",                         hl.dsp.exec_cmd("uwsm app -- {bin}/screenshot-area"))\n'
    f'hl.bind(mainMod .. " + Print",           hl.dsp.exec_cmd("uwsm app -- {bin}/screenshot-full"))\n'
    f'hl.bind(mainMod .. " + SHIFT + Print",   hl.dsp.exec_cmd("uwsm app -- {bin}/screenshot-window"))\n'
    f'hl.bind("CTRL + Print",                  hl.dsp.exec_cmd("{bin}/screenshot-copy"))\n'
)
content += block
with open(lua_path, 'w') as f:
    f.write(content)
print('LISTO')
PYEOF
        local _rc=$?
        if [[ $_rc -eq 0 ]]; then
            ok "Bindings Print configurados en hyprland.lua"
        else
            warn "Error al configurar bindings — agrégalos manualmente en hyprland.lua"
        fi
    else
        warn "No se encontró $lua — agrega manualmente los bindings Print"
        info "hl.bind(\"Print\",         hl.dsp.exec_cmd(\"screenshot-area\"))"
        info "hl.bind(\"SHIFT + Print\", hl.dsp.exec_cmd(\"screenshot-full\"))"
        info "hl.bind(\"ALT + Print\",   hl.dsp.exec_cmd(\"screenshot-window\"))"
        info "hl.bind(\"CTRL + Print\",  hl.dsp.exec_cmd(\"screenshot-copy\"))"
    fi
}

# ─── Confirmación salida Hyprland ─────────────────────────────────────────────
install_hypr_exit() {
    step "Configurando confirmación de salida (Super+M)..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    # Se sobrescribe siempre (archivo generado) para garantizar el THEME correcto.
    # Usa el tema unificado (current/rofi.rasi), no un tema fijo.
    cat > "$bin_dir/hypr-exit" << 'SCRIPT_EOF'
#!/usr/bin/env bash
THEME="$HOME/.config/omarchy/current/rofi.rasi"
ROFI_ARGS=(-dmenu -p "Sesión" -no-show-icons -no-custom -theme-str 'window {width: 28%;}')
[[ -f "$THEME" ]] && ROFI_ARGS+=(-theme "$THEME")

CHOICE=$(printf 'Cancelar\nBloquear\nSuspender\nSalir\nReiniciar\nApagar' | rofi "${ROFI_ARGS[@]}")

case "$CHOICE" in
    "Bloquear")  hyprlock & ;;
    "Suspender") systemctl suspend ;;
    "Salir")     uwsm stop || hyprctl dispatch exit ;;
    "Reiniciar") systemctl reboot ;;
    "Apagar")    systemctl poweroff ;;
esac
SCRIPT_EOF
    chmod +x "$bin_dir/hypr-exit"
    ok "hypr-exit instalado"

    # El template de Hyprland (/usr/share/hypr/hyprland.lua) trae Super+M como
    # 'hyprshutdown || hyprctl dispatch exit' — cierre directo sin confirmar.
    # Se reemplaza cualquier acción del bind Super+M por hypr-exit (ruta absoluta).
    if grep -q 'hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("'"${bin_dir}"'/hypr-exit"))' "$lua" 2>/dev/null; then
        ok "Binding Super+M ya apunta a hypr-exit"
    else
        sed -i "s#^hl.bind(mainMod .. \" + M\", hl.dsp.exec_cmd(.*\$#hl.bind(mainMod .. \" + M\", hl.dsp.exec_cmd(\"${bin_dir}/hypr-exit\"))#" "$lua"
        ok "Super+M actualizado con confirmación"
    fi
}

# ─── Show Keys ────────────────────────────────────────────────────────────────
install_show_keys() {
    step "Instalando show-keys (referencia de keybindings)..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    if [[ ! -f "$bin_dir/show-keys" ]]; then
        cat > "$bin_dir/show-keys" << 'SCRIPT_EOF'
#!/usr/bin/env bash
# Muestra la referencia de keybindings de Hyprland en rofi
THEME="$HOME/.config/rofi/themes/catppuccin-mocha.rasi"
ROFI_ARGS=(-dmenu -p "Keybindings" -i -no-show-icons -no-custom -theme-str 'window {width: 55%;}')
[[ -f "$THEME" ]] && ROFI_ARGS+=(-theme "$THEME")

cat <<'EOF' | rofi "${ROFI_ARGS[@]}"
── Aplicaciones ──────────────────────────────
Super + Q                →  Terminal (alacritty)
Super + E                →  Archivos (nautilus)
Super + Space            →  Lanzador (rofi)
Super + Ctrl + A         →  Audio (wiremix)
Super + Ctrl + V         →  Portapapeles (cliphist)
Super + Ctrl + B         →  Bluetooth (blueman)
Super + Ctrl + W         →  WiFi (nmtui)
Super + Ctrl + T         →  Monitor (btop)
Super + Ctrl + P         →  Pomodoro
Super + Shift + T        →  Selector de tema
Super + /                →  Esta ayuda
── Ventanas ──────────────────────────────────
Super + W                →  Cerrar ventana
Super + T                →  Flotante / tiling
Super + F                →  Pantalla completa
Super + Alt + F          →  Maximizar
Super + P                →  Pseudo-tile
Super + J                →  Cambiar split
Super + G                →  Agrupar ventanas
Super + Alt + Tab        →  Siguiente en grupo
── Foco ──────────────────────────────────────
Super + ← ↑ ↓ →         →  Enfocar ventana
Alt + Tab                →  Siguiente ventana
── Workspaces ────────────────────────────────
Super + 1-9 / 0          →  Ir a workspace
Super + Shift + 1-9 / 0  →  Mover ventana a workspace
Super + Tab              →  Workspace siguiente
Super + Shift + Tab      →  Workspace anterior
Super + Ctrl + Tab       →  Workspace anterior (historial)
Super + S                →  Scratchpad toggle
Super + Shift + S        →  Mover a scratchpad
── Sesión ────────────────────────────────────
Super + Ctrl + L         →  Bloquear pantalla
Super + M                →  Salir de Hyprland (con confirmación)
── Notificaciones ────────────────────────────
Super + ,                →  Descartar notificación
Super + Shift + ,        →  Descartar todas
── Capturas ──────────────────────────────────
Print                    →  Área → archivo
Shift + Print            →  Ventana → archivo
Alt + Print              →  Pantalla → archivo
Ctrl + Print             →  Área → portapapeles
EOF
SCRIPT_EOF
        chmod +x "$bin_dir/show-keys"
        ok "show-keys instalado en $bin_dir/show-keys"
    else
        ok "show-keys ya existe"
    fi

    if grep -q "show-keys" "$lua" 2>/dev/null; then
        ok "Binding Super+/ ya configurado"
    else
        python3 << 'PYEOF'
import sys, os
lua_path = os.path.expanduser('~/.config/hypr/hyprland.lua')
with open(lua_path) as f:
    content = f.read()
bin_dir = os.path.expanduser('~/.local/bin')
block = (
    '\n-- Referencia de keybindings\n'
    f'hl.bind(mainMod .. " + SLASH", hl.dsp.exec_cmd("{bin_dir}/show-keys"))\n'
)
content += block
with open(lua_path, 'w') as f:
    f.write(content)
print('LISTO')
PYEOF
        ok "Binding Super+/ añadido a hyprland.lua"
    fi
}

install_gpu_recorder() {
    header "GPU Screen Recorder"

    local lua="$HOME/.config/hypr/hyprland.lua"

    for pkg in gpu-screen-recorder gpu-screen-recorder-ui; do
        paru_install "$pkg"
    done
    paru_install --warn gpu-screen-recorder-notification

    mkdir -p "$HOME/Videos"

    if grep -q "gsr-ui" "$lua" 2>/dev/null; then
        ok "gsr-ui ya en autostart y keybinding"
    else
        python3 << 'PYEOF'
import os
lua_path = os.path.expanduser('~/.config/hypr/hyprland.lua')
with open(lua_path) as f:
    content = f.read()

# Autostart daemon
old = 'hl.exec_cmd("uwsm app -- udiskie --tray")'
new = old + '\n    hl.exec_cmd("uwsm app -- gsr-ui launch-daemon")'
content = content.replace(old, new, 1)

# Keybinding Super+Ctrl+R
content += '\n-- GPU Screen Recorder UI (Alt+Z abre el overlay)\n'
content += 'hl.bind(mainMod .. " + CTRL + R", hl.dsp.exec_cmd("gsr-ui launch-show"))\n'

with open(lua_path, 'w') as f:
    f.write(content)
print('LISTO')
PYEOF
        ok "gsr-ui añadido a autostart y binding Super+Ctrl+R"
    fi
}

# ─── Entradas .desktop para scripts locales ───────────────────────────────────
install_desktop_entries() {
    header "Entradas .desktop para rofi"

    local app_dir="$HOME/.local/share/applications"
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$app_dir"

    _desktop() {
        local file="$app_dir/$1"
        [[ -f "$file" ]] && { ok "$1 ya existe"; return; }
        cat > "$file" << EOF
$2
EOF
        ok "$1 creado"
    }

    _desktop "hypr-exit.desktop" "[Desktop Entry]
Type=Application
Name=Salir de Hyprland
Comment=Cierra la sesion de Hyprland con confirmacion
Icon=system-log-out
Exec=${bin_dir}/hypr-exit
Categories=System;
Keywords=salir;logout;exit;sesion;
NoDisplay=false"

    _desktop "show-keys.desktop" "[Desktop Entry]
Type=Application
Name=Referencia de atajos
Comment=Muestra los atajos de teclado de Hyprland
Icon=help-keybord-shortcuts
Exec=${bin_dir}/show-keys
Categories=Utility;
Keywords=atajos;keybindings;teclado;ayuda;
NoDisplay=false"

    _desktop "theme-switcher.desktop" "[Desktop Entry]
Type=Application
Name=Cambiar tema
Comment=Selector de temas Omarchy (21 temas disponibles)
Icon=preferences-desktop-theme
Exec=${bin_dir}/theme-switcher
Categories=Settings;
Keywords=tema;theme;color;apariencia;
NoDisplay=false"

    _desktop "screenshot-area.desktop" "[Desktop Entry]
Type=Application
Name=Captura de area
Comment=Selecciona un area de la pantalla y guarda la captura
Icon=applets-screenshooter
Exec=${bin_dir}/screenshot-area
Categories=Utility;Graphics;
Keywords=captura;screenshot;area;pantalla;
NoDisplay=false"

    _desktop "screenshot-full.desktop" "[Desktop Entry]
Type=Application
Name=Captura completa
Comment=Captura la pantalla completa y guarda el archivo
Icon=applets-screenshooter
Exec=${bin_dir}/screenshot-full
Categories=Utility;Graphics;
Keywords=captura;screenshot;pantalla;completa;
NoDisplay=false"

    _desktop "screenshot-window.desktop" "[Desktop Entry]
Type=Application
Name=Captura de ventana
Comment=Captura la ventana activa y guarda el archivo
Icon=applets-screenshooter
Exec=${bin_dir}/screenshot-window
Categories=Utility;Graphics;
Keywords=captura;screenshot;ventana;window;
NoDisplay=false"

    _desktop "screenshot-copy.desktop" "[Desktop Entry]
Type=Application
Name=Captura y anotar
Comment=Captura un area y abre satty para anotaciones
Icon=applets-screenshooter
Exec=${bin_dir}/screenshot-copy
Categories=Utility;Graphics;
Keywords=captura;screenshot;anotar;satty;
NoDisplay=false"

    _desktop "gsr-ui.desktop" "[Desktop Entry]
Type=Application
Name=Grabar pantalla (GPU Screen Recorder)
Comment=Overlay de grabacion con codificacion por GPU (VAAPI)
Icon=video-display
Exec=gsr-ui launch-show
Categories=Utility;Video;
Keywords=grabar;record;screen;pantalla;gsr;
NoDisplay=false"

    _desktop "pomodoro.desktop" "[Desktop Entry]
Type=Application
Name=Pomodoro
Comment=Temporizador Pomodoro con rofi y notificaciones
Icon=preferences-system-time
Exec=${bin_dir}/pomodoro
Categories=Utility;
Keywords=pomodoro;tiempo;temporizador;focus;concentracion;
NoDisplay=false"
}

install_tlp() {
    header "TLP — optimización de batería"

    if systemctl is-enabled --quiet tlp 2>/dev/null; then
        ok "tlp ya habilitado — omitiendo"
        return
    fi

    paru_install tlp
    sudo systemctl enable --now tlp

    ok "tlp activo (perfil automático AC/BAT)"
}

install_ufw() {
    header "Firewall (ufw)"

    if systemctl is-active --quiet ufw 2>/dev/null; then
        ok "ufw ya activo — omitiendo"
        return
    fi

    paru_install ufw

    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh comment 'SSH'
    sudo ufw allow 5353/udp comment 'mDNS avahi'
    sudo ufw allow in proto udp to any port 33434:33524 comment 'traceroute'
    sudo ufw --force enable
    sudo systemctl enable ufw

    ok "ufw activo"
}

install_keyring() {
    header "GNOME Keyring"

    local envdir="$HOME/.config/environment.d"
    local envfile="$envdir/gnome-keyring.conf"

    mkdir -p "$envdir"

    if [[ -f "$envfile" ]]; then
        ok "gnome-keyring.conf ya existe — omitiendo"
    else
        cat > "$envfile" << 'EOF'
GNOME_KEYRING_CONTROL=${XDG_RUNTIME_DIR}/keyring
EOF
        ok "environment.d/gnome-keyring.conf creado"
    fi

    if pgrep -x gnome-keyring-daemon &>/dev/null; then
        ok "gnome-keyring-daemon ya activo (PAM auto_start)"
    else
        warn "gnome-keyring-daemon no corre — se activará automáticamente al próximo login (vía pam_gnome_keyring.so en /etc/pam.d/sddm)"
    fi
}

install_cups() {
    header "Impresión (CUPS)"

    paru_install cups cups-browsed cups-filters cups-pdf system-config-printer

    systemctl is-enabled --quiet cups 2>/dev/null || sudo systemctl enable --now cups
    systemctl is-enabled --quiet cups-browsed 2>/dev/null || sudo systemctl enable --now cups-browsed

    if ! groups "$(whoami)" | grep -qw lp; then
        sudo usermod -aG lp "$(whoami)"
        ok "Usuario añadido al grupo lp (efecto en el próximo login)"
    else
        ok "Usuario ya en grupo lp"
    fi

    ok "cups activo"
}

# ─── Pomodoro ─────────────────────────────────────────────────────────────────
install_pomodoro() {
    step "Instalando pomodoro..."

    local lua="$HOME/.config/hypr/hyprland.lua"
    local bin_dir="$HOME/.local/bin"
    mkdir -p "$bin_dir"

    if [[ ! -f "$bin_dir/pomodoro" ]]; then
        cat > "$bin_dir/pomodoro" << 'SCRIPT_EOF'
#!/usr/bin/env bash

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/pomodoro-${UID}"
mkdir -p "$RUNTIME_DIR"
END_FILE="$RUNTIME_DIR/end"
PID_FILE="$RUNTIME_DIR/pid"

_running() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(< "$PID_FILE")" 2>/dev/null
}

_start() {
    local mins="${1:-25}"
    _stop 2>/dev/null
    bash -c "sleep $((mins * 60)) && notify-send 'Pomodoro' 'Sesion de ${mins} min completada.' --icon=alarm-symbolic --urgency=normal" &
    echo $! > "$PID_FILE"
    echo $(( $(date +%s) + mins * 60 )) > "$END_FILE"
    notify-send "Pomodoro" "Sesion de ${mins} min iniciada." --icon=alarm-symbolic --urgency=low
}

_stop() {
    [[ -f "$PID_FILE" ]] || return
    local pid
    pid=$(< "$PID_FILE")
    pkill -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
    rm -f "$PID_FILE" "$END_FILE"
}

_status() {
    if _running && [[ -f "$END_FILE" ]]; then
        local rem=$(( $(< "$END_FILE") - $(date +%s) ))
        (( rem > 0 )) && printf "%d:%02d restante" $(( rem/60 )) $(( rem%60 )) \
                      || echo "Finalizando..."
    else
        echo "Sin sesion activa"
    fi
}

THEME="$HOME/.config/rofi/themes/catppuccin-mocha.rasi"
ROFI_ARGS=(-dmenu -p "Pomodoro" -no-show-icons -no-custom
           -theme-str 'window {width: 300px;} listview {lines: 5;}')
[[ -f "$THEME" ]] && ROFI_ARGS+=(-theme "$THEME")

case "${1:-menu}" in
    start)  _start "${2:-25}" ;;
    stop)
        _stop
        notify-send "Pomodoro" "Sesion cancelada." --icon=alarm-symbolic --urgency=low 2>/dev/null
        ;;
    status) _status ;;
    menu)
        STATUS=$(_status)
        CHOICE=$(printf "Iniciar 25 min\nIniciar 50 min\nDescanso 5 min\nCancelar sesion\nEstado: %s" \
            "$STATUS" | rofi "${ROFI_ARGS[@]}")
        case "$CHOICE" in
            "Iniciar 25 min")  _start 25 ;;
            "Iniciar 50 min")  _start 50 ;;
            "Descanso 5 min")  _start 5 ;;
            "Cancelar sesion")
                _stop
                notify-send "Pomodoro" "Sesion cancelada." --icon=alarm-symbolic --urgency=low 2>/dev/null
                ;;
        esac
        ;;
    *) echo "Uso: pomodoro {start [mins]|stop|status|menu}" >&2; exit 1 ;;
esac
SCRIPT_EOF
        chmod +x "$bin_dir/pomodoro"
        ok "pomodoro instalado en $bin_dir/pomodoro"
    else
        ok "pomodoro ya existe"
    fi

    if [[ -f "$lua" ]] && grep -q 'pomodoro' "$lua"; then
        ok "Keybinding Super+Ctrl+P (pomodoro) ya existe"
    elif [[ -f "$lua" ]]; then
        python3 << 'PYEOF'
import os
lua_path = os.path.expanduser('~/.config/hypr/hyprland.lua')
with open(lua_path) as f:
    content = f.read()
bin_dir = os.path.expanduser('~/.local/bin')
block = f'\n-- Pomodoro\nhl.bind(mainMod .. " + CTRL + P", hl.dsp.exec_cmd("{bin_dir}/pomodoro"))\n'
content += block
with open(lua_path, 'w') as f:
    f.write(content)
print('LISTO')
PYEOF
        ok "Keybinding Super+Ctrl+P (pomodoro) añadido"
    else
        warn "No se encontró $lua — agrega manualmente: hl.bind(mainMod .. \" + CTRL + P\", hl.dsp.exec_cmd(\"pomodoro\"))"
    fi
}

# ─── Monitor Setup y Listener ────────────────────────────────────────────────
install_monitor_setup() {
    header "Monitores Dinámicos y Listener"

    local lua="$HOME/.config/hypr/hyprland.lua"
    local bin_dir="$HOME/.local/bin"
    local app_dir="$HOME/.local/share/applications"
    mkdir -p "$bin_dir" "$app_dir"

    # 1. Instalar hypr-monitor-setup
    cat > "$bin_dir/hypr-monitor-setup" << 'SETUP_EOF'
#!/usr/bin/env bash
# hypr-monitor-setup — Configuración de monitores + workspaces
# Uso: Super+Ctrl+M (interactivo) o llamado con --auto por el listener
# Requiere: jq, rofi, hyprctl, notify-send, awk
# NOTA: Usa `hyprctl eval` (Lua) para config no-legacy

PROFILE_FILE="$HOME/.config/hypr/monitor-profile.sh"

# Dependencias
for dep in jq rofi hyprctl notify-send awk; do
    command -v "$dep" &>/dev/null || { echo "[hypr-monitor] ERROR: '$dep' no encontrado" >&2; exit 1; }
done

# Obtener monitores conectados
sleep 1
monitors_json=$(hyprctl monitors -j 2>/dev/null)
monitor_count=$(echo "$monitors_json" | jq 'length')

# Detectar pantallas físicas presentes
has_ktc=$(echo "$monitors_json" | jq -e '.[] | select(.name=="HDMI-A-1")' &>/dev/null && echo "true" || echo "false")
has_samsung=$(echo "$monitors_json" | jq -e '.[] | select(.name=="HDMI-A-2")' &>/dev/null && echo "true" || echo "false")
has_tv=$(echo "$monitors_json" | jq -e '.[] | select(.name=="DP-2")' &>/dev/null && echo "true" || echo "false")

apply_profile_doble() {
    {
        echo '#!/usr/bin/env bash'
        echo "# Perfil generado automáticamente: Doble Monitor"
        echo "# Fecha: $(date '+%Y-%m-%d %H:%M')"
        echo ""
        echo "# --- Monitores ---"
        echo "hyprctl eval \"hl.monitor({output=\\\"HDMI-A-2\\\", mode=\\\"1366x768@60\\\", position=\\\"0x0\\\", scale=\\\"1\\\"})\""
        echo "hyprctl eval \"hl.monitor({output=\\\"HDMI-A-1\\\", mode=\\\"1920x1080@60\\\", position=\\\"1366x0\\\", scale=\\\"1\\\"})\""
        echo ""
        echo "# --- Workspaces ---"
        for w in {1..5}; do
            df="false"; [[ "$w" -eq 1 ]] && df="true"
            echo "hyprctl eval \"hl.workspace_rule({workspace=\\\"$w\\\", monitor=\\\"HDMI-A-2\\\", persistent=true, default=$df})\""
        done
        for w in {6..10}; do
            df="false"; [[ "$w" -eq 6 ]] && df="true"
            echo "hyprctl eval \"hl.workspace_rule({workspace=\\\"$w\\\", monitor=\\\"HDMI-A-1\\\", persistent=true, default=$df})\""
        done
    } > "$PROFILE_FILE"
    
    chmod +x "$PROFILE_FILE"
    bash "$PROFILE_FILE"
    
    notify-send "🖥️ Perfil Doble" "Samsung (Izq) + KTC (Principal)\nWorkspaces: 1-5 / 6-10" --urgency=low --expire-time=4000
}

apply_profile_unico() {
    local mon_name="HDMI-A-1"
    [[ "$has_ktc" == "false" && "$has_samsung" == "true" ]] && mon_name="HDMI-A-2"
    local mode="1920x1080@60"
    [[ "$mon_name" == "HDMI-A-2" ]] && mode="1366x768@60"
    
    {
        echo '#!/usr/bin/env bash'
        echo "# Perfil generado automáticamente: Monitor Único"
        echo "# Fecha: $(date '+%Y-%m-%d %H:%M')"
        echo ""
        echo "# --- Monitores ---"
        echo "hyprctl eval \"hl.monitor({output=\\\"$mon_name\\\", mode=\\\"$mode\\\", position=\\\"0x0\\\", scale=\\\"1\\\"})\""
        echo ""
        echo "# --- Workspaces ---"
        for w in {1..10}; do
            df="false"; [[ "$w" -eq 1 ]] && df="true"
            echo "hyprctl eval \"hl.workspace_rule({workspace=\\\"$w\\\", monitor=\\\"$mon_name\\\", persistent=true, default=$df})\""
        done
    } > "$PROFILE_FILE"
    
    chmod +x "$PROFILE_FILE"
    bash "$PROFILE_FILE"
    
    notify-send "🖥️ Perfil Único" "$mon_name configurado.\nWorkspaces: 1-10" --urgency=low --expire-time=4000
}

apply_profile_triple() {
    {
        echo '#!/usr/bin/env bash'
        echo "# Perfil generado automáticamente: Triple Monitor"
        echo "# Fecha: $(date '+%Y-%m-%d %H:%M')"
        echo ""
        echo "# --- Monitores ---"
        echo "hyprctl eval \"hl.monitor({output=\\\"HDMI-A-2\\\", mode=\\\"1366x768@60\\\", position=\\\"0x0\\\", scale=\\\"1\\\"})\""
        echo "hyprctl eval \"hl.monitor({output=\\\"HDMI-A-1\\\", mode=\\\"1920x1080@60\\\", position=\\\"1366x0\\\", scale=\\\"1\\\"})\""
        echo "hyprctl eval \"hl.monitor({output=\\\"DP-2\\\", mode=\\\"1920x1080@60\\\", position=\\\"3286x0\\\", scale=\\\"2\\\"})\""
        echo ""
        echo "# --- Workspaces ---"
        for w in {1..4}; do
            df="false"; [[ "$w" -eq 1 ]] && df="true"
            echo "hyprctl eval \"hl.workspace_rule({workspace=\\\"$w\\\", monitor=\\\"HDMI-A-2\\\", persistent=true, default=$df})\""
        done
        for w in {5..8}; do
            df="false"; [[ "$w" -eq 5 ]] && df="true"
            echo "hyprctl eval \"hl.workspace_rule({workspace=\\\"$w\\\", monitor=\\\"HDMI-A-1\\\", persistent=true, default=$df})\""
        done
        for w in {9..10}; do
            df="false"; [[ "$w" -eq 9 ]] && df="true"
            echo "hyprctl eval \"hl.workspace_rule({workspace=\\\"$w\\\", monitor=\\\"DP-2\\\", persistent=true, default=$df})\""
        done
    } > "$PROFILE_FILE"
    
    chmod +x "$PROFILE_FILE"
    bash "$PROFILE_FILE"
    
    notify-send "🖥️ Perfil Triple" "Samsung (Izq) + KTC (Centro) + TV (Der)" --urgency=low --expire-time=4000
}

if [[ "$1" == "--auto" ]]; then
    if [[ "$has_ktc" == "true" && "$has_samsung" == "true" && "$has_tv" == "true" ]]; then
        apply_profile_triple
    elif [[ "$has_ktc" == "true" && "$has_samsung" == "true" ]]; then
        apply_profile_doble
    else
        apply_profile_unico
    fi
    exit 0
fi

options=""
if [[ "$has_ktc" == "true" && "$has_samsung" == "true" && "$has_tv" == "true" ]]; then
    options="3 🖥️  Triple: Samsung (Izq) + KTC (Centro) + TV (Der)
1 🖥️  Doble: Samsung (Izq) + KTC (Centro)
2 🖥️  Único: KTC Principal"
elif [[ "$has_ktc" == "true" && "$has_samsung" == "true" ]]; then
    options="1 🖥️  Doble: Samsung (Izq) + KTC (Centro)
2 🖥️  Único: KTC Principal
3 🖥️  Triple: Samsung (Izq) + KTC (Centro) + TV (Der)"
else
    options="2 🖥️  Único: KTC Principal
1 🖥️  Doble: Samsung (Izq) + KTC (Centro)
3 🖥️  Triple: Samsung (Izq) + KTC (Centro) + TV (Der)"
fi

choice=$(echo "$options" | rofi -dmenu \
    -p "🖥️  Perfil de Monitores" \
    -mesg "Selecciona el perfil de pantallas a aplicar:" \
    -i -theme-str 'window {width: 600px;} listview {lines: 3;}' 2>/dev/null)

[[ -z "$choice" ]] && { echo "[hypr-monitor] Cancelado"; exit 0; }

case "$choice" in
    *Doble*)  apply_profile_doble ;;
    *Único*)  apply_profile_unico ;;
    *Triple*) apply_profile_triple ;;
esac
SETUP_EOF

    # 2. Instalar hypr-monitor-listener
    cat > "$bin_dir/hypr-monitor-listener" << 'LISTENER_EOF'
#!/usr/bin/env bash
# hypr-monitor-listener — Daemon de eventos de monitor para Hyprland
# Detecta conexion/desconexion de monitores y aplica layouts de forma automática
# Requiere: socat, hyprctl, notify-send

SETUP_SCRIPT="$HOME/.local/bin/hypr-monitor-setup"

log() { echo "[hypr-monitor-listener] $(date '+%H:%M:%S') $*"; }

if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    log "ERROR: HYPRLAND_INSTANCE_SIGNATURE no definida."
    exit 1
fi

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
if [[ ! -S "$SOCKET" ]]; then
    log "ERROR: Socket no encontrado: $SOCKET"
    exit 1
fi

log "Detectando monitores al inicializar..."
sleep 2
bash "$SETUP_SCRIPT" --auto

log "Escuchando eventos de monitor en $SOCKET"

socat - "UNIX-CONNECT:$SOCKET" | while IFS= read -r line; do
    case "$line" in
        monitoradded*)
            log "Monitor CONECTADO"
            sleep 1
            bash "$SETUP_SCRIPT" --auto
            ;;
        monitorremoved*)
            log "Monitor DESCONECTADO"
            sleep 1
            bash "$SETUP_SCRIPT" --auto
            ;;
    esac
done
LISTENER_EOF

    # 3. Instalar acceso directo .desktop
    cat > "$app_dir/hypr-monitor-setup.desktop" << 'DESKTOP_EOF'
[Desktop Entry]
Name=Configuración de Monitores
GenericName=Gestor de Pantallas
Comment=Configura perfiles de monitores y workspaces de forma rápida
Exec=$HOME/.local/bin/hypr-monitor-setup
Icon=video-display
Terminal=false
Type=Application
Categories=Settings;HardwareSettings;
Keywords=monitor;pantalla;display;layout;hyprland;
DESKTOP_EOF

    chmod +x "$bin_dir/hypr-monitor-setup" "$bin_dir/hypr-monitor-listener"
    ok "Scripts y acceso directo de monitores configurados"

    # 4. Asegurar keybinding
    if [[ -f "$lua" ]] && grep -q 'hypr-monitor-setup' "$lua"; then
        ok "Keybinding Super+Ctrl+M (monitores) ya existe"
    elif [[ -f "$lua" ]]; then
        python3 << 'PYEOF'
import os
lua_path = os.path.expanduser('~/.config/hypr/hyprland.lua')
with open(lua_path) as f:
    content = f.read()
bin_dir = os.path.expanduser('~/.local/bin')
block = f'\n-- Reconfigurar monitores + workspaces (GUI interactivo via rofi)\nhl.bind(mainMod .. " + CTRL + M", hl.dsp.exec_cmd("{bin_dir}/hypr-monitor-setup"))\n'
content += block
with open(lua_path, 'w') as f:
    f.write(content)
PYEOF
        ok "Keybinding Super+Ctrl+M (monitores) añadido"
    fi

    # 5. Asegurar autostart
    if [[ -f "$lua" ]] && grep -q 'hypr-monitor-listener' "$lua"; then
        ok "Autostart de hypr-monitor-listener ya existe"
    elif [[ -f "$lua" ]]; then
        python3 << 'PYEOF'
import os
lua_path = os.path.expanduser('~/.config/hypr/hyprland.lua')
with open(lua_path) as f:
    content = f.read()
if 'hl.on("hyprland.start", function()' in content:
    target = 'hl.on("hyprland.start", function()'
    idx = content.find(target) + len(target)
    addition = '\n    hl.exec_cmd("uwsm app -- ~/.local/bin/hypr-monitor-listener")'
    content = content[:idx] + addition + content[idx:]
    with open(lua_path, 'w') as f:
        f.write(content)
PYEOF
        ok "Autostart de hypr-monitor-listener añadido"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    header "Personalización escritorio Hyprland"
    check_prereqs
    configure_mirrors
    update_system
    init_hyprland_config
    install_fonts
    install_waybar
    install_nm_applet
    install_audio
    install_swayosd
    install_bluetooth
    install_udiskie
    install_polkit
    install_xdg_portal
    is_laptop && install_touchpad
    install_kb_switch
    install_alacritty

    install_hyprsunset
    install_hyprlock
    install_idle_settings
    install_eww
    install_wiremix
    install_mako
    install_rofi
    install_cliphist
    install_wallpaper
    install_apps
    install_theme
    install_omarchy_bindings
    install_theme_switcher
    install_dns
    is_laptop && install_tlp
    install_ufw
    install_screenshots
    install_hypr_exit
    install_show_keys
    install_gpu_recorder
    install_desktop_entries
    install_keyring
    install_cups
    install_pomodoro
    install_monitor_setup

    echo -e "\n${BOLD}${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    printf "${BOLD}${GREEN}║  %-52s║${NC}\n" "Instalacion completada"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo -e "   ${GREEN}✓  Escritorio Hyprland configurado${NC}"
    echo -e "   ${DIM}→  Reinicia para aplicar todos los cambios:${NC}"
    echo -e "   ${BOLD}      sudo reboot${NC}"
    echo -e "   ${DIM}→  Gaming (opcional): bash install-gaming.sh${NC}\n"
}

main "$@"
