#!/bin/bash
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ install-base.sh                                                              │
# │ Instalación del sistema base CachyOS desde Live USB                         │
# │                                                                              │
# │ Cubre los capítulos 1-10 del manual:                                         │
# │   particionado BTRFS · subvolúmenes · pacstrap · GRUB · snapper · usuario  │
# │                                                                              │
# │ Ejecutar como root desde el Live USB:  bash install-base.sh                 │
# └─────────────────────────────────────────────────────────────────────────────┘

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
LOG_FILE="$SCRIPT_DIR/install-base.log"

# ─── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ─── Trap de error inesperado ─────────────────────────────────────────────────
_on_error() {
    echo -e "\n${RED}${BOLD}ERROR  Fallo inesperado — línea $1: $2${NC}" >&2
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
step()    { echo -e "\n${BOLD}▶  $1${NC}"; }
ok()      { echo -e "   ${GREEN}OK  $1${NC}"; }
warn()    { echo -e "   ${YELLOW}AVISO  $1${NC}"; }
info()    { echo -e "   ${DIM}→  $1${NC}"; }
die()     { echo -e "\n   ${RED}ERROR  $1${NC}\n" >&2; exit 1; }

ask() {
    local prompt="$1" var="$2" default="${3:-}"
    if [[ -n "$default" ]]; then
        printf "\n${CYAN}   %s [%s]: ${NC}" "$prompt" "$default"
    else
        printf "\n${CYAN}   %s: ${NC}" "$prompt"
    fi
    read -r "$var" < /dev/tty
    [[ -z "${!var}" && -n "$default" ]] && printf -v "$var" '%s' "$default"
}

ask_number() {
    local prompt="$1" var="$2" default="${3:-}" response
    while true; do
        if [[ -n "$default" ]]; then
            printf "\n${CYAN}   %s [%s]: ${NC}" "$prompt" "$default"
        else
            printf "\n${CYAN}   %s: ${NC}" "$prompt"
        fi
        read -r response < /dev/tty
        # Si presiona Enter y hay default → aceptar directamente (sin validación)
        if [[ -z "$response" ]]; then
            if [[ -n "$default" ]]; then
                printf -v "$var" '%s' "$default"
                break
            else
                warn "Debes escribir un número"
                continue
            fi
        fi
        # Si escribió algo → debe ser número positivo
        if [[ "$response" =~ ^[0-9]+$ ]] && (( response >= 1 )); then
            printf -v "$var" '%s' "$response"
            break
        else
            warn "Entrada inválida — escribe un número válido (ej: 4, 8, 16, 32)"
        fi
    done
}

askpass() {
    local prompt="$1" var="$2"
    local pass1 pass2
    while true; do
        printf "\n${CYAN}   %s: ${NC}" "$prompt"
        read -rs pass1 < /dev/tty; echo
        printf "${CYAN}   Confirmar: ${NC}"
        read -rs pass2 < /dev/tty; echo
        [[ "$pass1" == "$pass2" ]] && break
        warn "No coinciden, intenta de nuevo."
    done
    printf -v "$var" '%s' "$pass1"
}

confirm() {
    local response
    while true; do
        printf "\n${CYAN}   %s [s/N]: ${NC}" "$1"
        read -r response < /dev/tty
        case "$response" in
            [sS]) return 0 ;;
            [nN]|"") return 1 ;;
            *) warn "Respuesta inválida — escribe 's' para Sí o 'N' para No" ;;
        esac
    done
}

# ─── Variables globales ───────────────────────────────────────────────────────
TARGET_DISK=""
EFI_PART=""
BTRFS_PART=""
BTRFS_DEV=""        # = BTRFS_PART, o /dev/mapper/cryptroot si LUKS

SYS_HOSTNAME=""
USERNAME=""
USERPASS=""
TIMEZONE="America/Caracas"
LOCALE="es_VE.UTF-8"
KEYMAP="us"        # vconsole (/etc/vconsole.conf)
XKB_LAYOUT="us"   # X11/Wayland (SDDM + Hyprland)
XKB_VARIANT=""

USE_LUKS=false
LUKS_PASS=""
USE_HIBERNATE=false
USE_DOCKER=false
SHELL_CHOICE="none"

SWAP_SIZE=4
RAM_GB=0
GPU_TYPE=""
EXTRA_KERNEL_PARAMS=""
SWAP_OFFSET=0

# ─── 1. Verificaciones previas ────────────────────────────────────────────────
check_prereqs() {
    header "Verificando requisitos"

    [[ $EUID -eq 0 ]]          || die "Ejecuta el script como root: sudo bash install-base.sh"
    ok "Ejecutando como root"

    [[ -d /sys/firmware/efi ]] || die "No se detectó modo UEFI. Arranca el equipo en modo UEFI."
    ok "Modo UEFI"

    ping -c 1 -W 3 archlinux.org &>/dev/null || die "Sin conexión a Internet."
    ok "Internet activo"

    command -v pacstrap &>/dev/null || die "pacstrap no encontrado. ¿Estás en el Live USB de CachyOS?"
    ok "Entorno Live USB correcto"
}

# ─── 2. Detección de GPU ──────────────────────────────────────────────────────
detect_gpu() {
    header "Detección de GPU"
    local vga
    vga=$(lspci | grep -Ei "VGA|3D|Display" | head -1)

    if   echo "$vga" | grep -qi intel;       then GPU_TYPE="intel";  EXTRA_KERNEL_PARAMS="i915.enable_psr=0"
    elif echo "$vga" | grep -qi "amd\|ati";  then GPU_TYPE="amd"
    elif echo "$vga" | grep -qi nvidia;      then GPU_TYPE="nvidia"
    else GPU_TYPE="unknown"; warn "GPU no reconocida: $vga"
    fi

    ok "GPU: $GPU_TYPE${EXTRA_KERNEL_PARAMS:+ — params: $EXTRA_KERNEL_PARAMS}"
}

# ─── 3. Detección de RAM y cálculo de swap ────────────────────────────────────
detect_ram() {
    RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024 + 0.5}' /proc/meminfo)
    ok "RAM: ${RAM_GB} GB"
}

suggest_swap() {
    # $1 = true (hibernación) | false (sin hibernación)
    if [[ "$1" == "true" ]]; then
        if   [[ $RAM_GB -le 2 ]];  then echo 4
        elif [[ $RAM_GB -le 8 ]];  then echo $(( RAM_GB * 2 ))
        elif [[ $RAM_GB -le 64 ]]; then echo $(( RAM_GB * 3 / 2 ))
        else echo 8; fi
    else
        if   [[ $RAM_GB -le 2 ]];  then echo 4
        elif [[ $RAM_GB -le 8 ]];  then echo $RAM_GB
        elif [[ $RAM_GB -le 64 ]]; then echo 16
        else echo 8; fi
    fi
}

# ─── Validación de disco limpio ────────────────────────────────────────────────
validate_disk_clean() {
    local disk="$1"
    # Verificar si hay tabla de particiones o datos en el disco
    if wipefs -n "$disk" 2>/dev/null | grep -q .; then
        warn "El disco $disk contiene datos previos."
        echo ""
        if confirm "¿Limpiar el disco ahora con wipefs -a $disk?"; then
            step "Limpiando $disk..."
            wipefs -a "$disk"
            partprobe "$disk" 2>/dev/null || true
            ok "Disco $disk limpiado correctamente"
            return
        fi
        echo -e "\n   ${BOLD}Para limpiar manualmente:${NC}\n"
        echo -e "   ${CYAN}Opción 1 (rápida):${NC}"
        echo -e "   ${DIM}sudo wipefs -a $disk${NC}"
        echo ""
        echo -e "   ${CYAN}Opción 2 (más segura, borra primeros 100 MB):${NC}"
        echo -e "   ${DIM}sudo dd if=/dev/zero of=$disk bs=1M count=100 && sync${NC}"
        echo ""
        die "Disco no limpio. Reinicia el script tras limpiarlo."
    fi
    ok "Disco $disk está limpio"
}

# ─── Selección de zona horaria ───────────────────────────────────────────────
ask_timezone() {
    local zones
    mapfile -t zones < <(timedatectl list-timezones 2>/dev/null)
    [[ ${#zones[@]} -eq 0 ]] && {
        ask "Zona horaria (ej: America/Caracas)" TIMEZONE "America/Caracas"
        [[ -f "/usr/share/zoneinfo/$TIMEZONE" ]] || die "Zona horaria inválida: $TIMEZONE"
        return
    }

    local total=${#zones[@]}
    local per_page=25
    local page=0

    while true; do
        local start=$(( page * per_page ))
        local end=$(( start + per_page < total ? start + per_page : total ))

        echo -e "\n   ${BOLD}Zona horaria${NC}  ${DIM}($(( start + 1 ))–${end} de ${total})${NC}\n"
        for (( i = start; i < end; i++ )); do
            printf "   %4d)  %s\n" $(( i + 1 )) "${zones[$i]}"
        done
        echo -e "\n   ${DIM}[número] seleccionar · [n] siguiente · [p] anterior · [b] buscar${NC}"
        printf "${CYAN}   Opción: ${NC}"
        read -r _tz < /dev/tty

        if [[ "$_tz" =~ ^[0-9]+$ ]] && (( _tz >= 1 && _tz <= total )); then
            TIMEZONE="${zones[$(( _tz - 1 ))]}"
            ok "Zona horaria: $TIMEZONE"
            return
        elif [[ "$_tz" == "n" ]]; then
            (( (page + 1) * per_page < total )) && (( page++ )) || true
        elif [[ "$_tz" == "p" ]]; then
            (( page > 0 )) && (( page-- )) || true
        elif [[ "$_tz" == "b" ]]; then
            printf "   ${CYAN}Buscar (ej: Caracas, America, Madrid): ${NC}"
            read -r _query < /dev/tty
            local results=()
            local _q="${_query,,}"
            for z in "${zones[@]}"; do
                [[ "${z,,}" == *"$_q"* ]] && results+=("$z")
            done
            if [[ ${#results[@]} -eq 0 ]]; then
                warn "Sin resultados para '$_query'"
            elif [[ ${#results[@]} -eq 1 ]]; then
                TIMEZONE="${results[0]}"
                ok "Zona horaria: $TIMEZONE"
                return
            else
                echo -e "\n   ${BOLD}Resultados para '$_query':${NC}\n"
                for (( i = 0; i < ${#results[@]}; i++ )); do
                    printf "   %4d)  %s\n" $(( i + 1 )) "${results[$i]}"
                done
                printf "\n${CYAN}   Número: ${NC}"
                read -r _num < /dev/tty
                if [[ "$_num" =~ ^[0-9]+$ ]] && (( _num >= 1 && _num <= ${#results[@]} )); then
                    TIMEZONE="${results[$(( _num - 1 ))]}"
                    ok "Zona horaria: $TIMEZONE"
                    return
                else
                    warn "Entrada inválida — regresando al menú"
                fi
            fi
        else
            warn "Entrada inválida"
        fi
    done
}

# ─── Selección de locale ──────────────────────────────────────────────────────
ask_locale() {
    echo -e "\n   ${BOLD}Locale del sistema:${NC}\n"
    echo -e "    1)  es_VE.UTF-8  — Español Venezuela  ${GREEN}[recomendado]${NC}"
    echo -e "    2)  es_ES.UTF-8  — Español España"
    echo -e "    3)  es_MX.UTF-8  — Español México"
    echo -e "    4)  es_AR.UTF-8  — Español Argentina"
    echo -e "    5)  es_CO.UTF-8  — Español Colombia"
    echo -e "    6)  es_CL.UTF-8  — Español Chile"
    echo -e "    7)  en_US.UTF-8  — Inglés EE.UU."
    echo -e "    8)  en_GB.UTF-8  — Inglés Reino Unido"
    echo -e "    9)  fr_FR.UTF-8  — Francés Francia"
    echo -e "   10)  de_DE.UTF-8  — Alemán Alemania"
    echo -e "   11)  pt_BR.UTF-8  — Portugués Brasil"
    echo -e "   12)  pt_PT.UTF-8  — Portugués Portugal"
    echo -e "   13)  it_IT.UTF-8  — Italiano Italia"
    echo -e "   14)  ru_RU.UTF-8  — Ruso"
    echo -e "   15)  ja_JP.UTF-8  — Japonés"
    echo -e "    0)  Otro         — entrada manual\n"

    printf "${CYAN}   Opción [1]: ${NC}"
    read -r _loc < /dev/tty
    _loc="${_loc:-1}"

    case "$_loc" in
        1)  LOCALE="es_VE.UTF-8" ;;
        2)  LOCALE="es_ES.UTF-8" ;;
        3)  LOCALE="es_MX.UTF-8" ;;
        4)  LOCALE="es_AR.UTF-8" ;;
        5)  LOCALE="es_CO.UTF-8" ;;
        6)  LOCALE="es_CL.UTF-8" ;;
        7)  LOCALE="en_US.UTF-8" ;;
        8)  LOCALE="en_GB.UTF-8" ;;
        9)  LOCALE="fr_FR.UTF-8" ;;
        10) LOCALE="de_DE.UTF-8" ;;
        11) LOCALE="pt_BR.UTF-8" ;;
        12) LOCALE="pt_PT.UTF-8" ;;
        13) LOCALE="it_IT.UTF-8" ;;
        14) LOCALE="ru_RU.UTF-8" ;;
        15) LOCALE="ja_JP.UTF-8" ;;
        0)
            ask "Locale (ej: es_VE.UTF-8)" LOCALE "es_VE.UTF-8"
            [[ -n "$LOCALE" ]] || die "Locale no puede estar vacío."
            ;;
        *)  warn "Opción inválida, usando es_VE.UTF-8"
            LOCALE="es_VE.UTF-8" ;;
    esac

    ok "Locale: $LOCALE"
}

# ─── Selección de teclado ────────────────────────────────────────────────────
ask_keyboard() {
    echo -e "\n   ${BOLD}Distribución de teclado:${NC}"
    echo -e "   ${DIM}Elige un número o escribe 0 para entrada manual.${NC}\n"
    echo -e "   1)  us              — Inglés estándar (sin acentos)"
    echo -e "   2)  us / altgr-intl — Inglés + AltGr para á é í ó ú ñ ¿ ¡  ${GREEN}[recomendado para español en teclado US]${NC}"
    echo -e "   3)  es              — Español España"
    echo -e "   4)  latam           — Latinoamérica"
    echo -e "   5)  fr              — Francés"
    echo -e "   6)  de              — Alemán"
    echo -e "   7)  pt              — Portugués"
    echo -e "   8)  ru              — Ruso"
    echo -e "   0)  Otro            — ingresar manualmente\n"

    printf "${CYAN}   Opción [2]: ${NC}"
    read -r _kb < /dev/tty
    _kb="${_kb:-2}"

    case "$_kb" in
        1) KEYMAP="us";         XKB_LAYOUT="us";    XKB_VARIANT="" ;;
        2) KEYMAP="us";         XKB_LAYOUT="us";    XKB_VARIANT="altgr-intl" ;;
        3) KEYMAP="es";         XKB_LAYOUT="es";    XKB_VARIANT="" ;;
        4) KEYMAP="la-latin1";  XKB_LAYOUT="latam"; XKB_VARIANT="" ;;
        5) KEYMAP="fr";         XKB_LAYOUT="fr";    XKB_VARIANT="" ;;
        6) KEYMAP="de";         XKB_LAYOUT="de";    XKB_VARIANT="" ;;
        7) KEYMAP="pt-latin1";  XKB_LAYOUT="pt";    XKB_VARIANT="" ;;
        8) KEYMAP="ru";         XKB_LAYOUT="ru";    XKB_VARIANT="" ;;
        0)
            ask "vconsole keymap (ej: us, es, fr)" KEYMAP "us"
            ask "XKB layout     (ej: us, es, latam)" XKB_LAYOUT "$KEYMAP"
            ask "XKB variant    (ej: altgr-intl, intl — dejar vacío si no aplica)" XKB_VARIANT ""
            ;;
        *) warn "Opción inválida, usando us/altgr-intl"
           KEYMAP="us"; XKB_LAYOUT="us"; XKB_VARIANT="altgr-intl" ;;
    esac

    local desc="$XKB_LAYOUT"
    [[ -n "$XKB_VARIANT" ]] && desc="$XKB_LAYOUT / $XKB_VARIANT"
    ok "Teclado: $desc  (vconsole: $KEYMAP)"
}

# ─── 4. Preguntas al usuario ──────────────────────────────────────────────────
ask_questions() {
    header "Configuración de la instalación"

    # ── Disco ─────────────────────────────────────────────────────────────────
    echo -e "\n   ${BOLD}Discos disponibles:${NC}"
    local disk_list=()
    while IFS= read -r line; do
        disk_list+=("$line")
    done < <(lsblk -dpno NAME,SIZE,MODEL | grep -Ev "loop|sr|zram")

    local i=1
    for entry in "${disk_list[@]}"; do
        printf "      %s) %s\n" "$i" "$(echo "$entry" | awk '{printf "%-16s %-8s %s", $1, $2, $3}')"
        (( i++ ))
    done
    echo ""

    local selection
    while true; do
        printf "   Selecciona disco [1-%d]: " "${#disk_list[@]}"
        read -r selection < /dev/tty
        if [[ "$selection" =~ ^[0-9]+$ ]] && (( selection >= 1 && selection <= ${#disk_list[@]} )); then
            TARGET_DISK=$(echo "${disk_list[$((selection-1))]}" | awk '{print $1}')
            break
        fi
        echo -e "   ${RED}Opción inválida — ingresa un número entre 1 y ${#disk_list[@]}${NC}"
    done
    ok "Disco seleccionado: $TARGET_DISK"
    [[ -b "$TARGET_DISK" ]] || die "Disco no encontrado: $TARGET_DISK"

    # ── Verificación de disco limpio ──────────────────────────────────────────
    if wipefs -n "$TARGET_DISK" 2>/dev/null | grep -q .; then
        warn "El disco $TARGET_DISK contiene datos previos."
        echo ""
        if confirm "¿Limpiar el disco ahora con wipefs -a $TARGET_DISK?"; then
            step "Limpiando $TARGET_DISK..."
            wipefs -a "$TARGET_DISK"
            partprobe "$TARGET_DISK" 2>/dev/null || true
            ok "Disco $TARGET_DISK limpiado correctamente"
        else
            echo -e "\n   ${CYAN}Para limpiar manualmente:${NC}  sudo wipefs -a $TARGET_DISK\n"
            die "Disco no limpio. Reinicia el script tras limpiarlo."
        fi
    else
        ok "Disco $TARGET_DISK está limpio"
    fi

    # ── Sistema ───────────────────────────────────────────────────────────────
    ask "Nombre del equipo (hostname)" SYS_HOSTNAME
    [[ -n "$SYS_HOSTNAME" ]] || die "El hostname no puede estar vacío."

    ask "Nombre de usuario" USERNAME
    [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] \
        || die "Usuario inválido: solo letras minúsculas, números, _ y -"

    askpass "Contraseña para $USERNAME" USERPASS
    [[ -n "$USERPASS" ]] || die "La contraseña no puede estar vacía."

    ask_timezone
    ask_locale
    ask_keyboard

    # ── LUKS ──────────────────────────────────────────────────────────────────
    if confirm "¿Cifrado completo del disco con LUKS2?"; then
        USE_LUKS=true
        askpass "Passphrase LUKS (se pedirá en cada arranque)" LUKS_PASS
        [[ ${#LUKS_PASS} -ge 8 ]] || die "Passphrase demasiado corta (mínimo 8 caracteres)."
        ok "Cifrado LUKS2 habilitado"
    fi

    # ── Hibernación y swap ────────────────────────────────────────────────────
    echo -e "\n   ${BOLD}RAM detectada: ${RAM_GB} GB${NC}"
    echo -e "   ${DIM}Referencia swap:${NC}"
    echo -e "   ${DIM}  Sin hibernación: $(suggest_swap false) GB sugeridos${NC}"
    echo -e "   ${DIM}  Con hibernación: $(suggest_swap true) GB sugeridos${NC}"

    if confirm "¿Soporte de hibernación (suspend-to-disk)?"; then
        USE_HIBERNATE=true
        SWAP_SIZE=$(suggest_swap true)
        info "Swap calculada para hibernación: ${SWAP_SIZE} GB"
    else
        SWAP_SIZE=$(suggest_swap false)
        info "Swap sugerida: ${SWAP_SIZE} GB"
    fi
    ask_number "Tamaño del swap en GB" SWAP_SIZE "$SWAP_SIZE"

    # ── Docker ────────────────────────────────────────────────────────────────
    if confirm "¿Subvolumen @docker para /var/lib/docker? (recomendado si usarás Docker)"; then
        USE_DOCKER=true
        ok "Subvolumen @docker incluido"
    fi

    # ── Shell interactivo ─────────────────────────────────────────────────────
    echo -e "\n   ${BOLD}Mejora del shell interactivo:${NC}"
    echo -e "   1) Bash mejorado — ble.sh + Oh My Bash (syntax highlighting, autosuggestions)"
    echo -e "   2) ZSH con plugins — zsh-syntax-highlighting + zsh-autosuggestions"
    echo -e "   3) Ninguno"
    while true; do
        printf "\n${CYAN}   Selección [1-3]: ${NC}"
        read -r _shell_resp < /dev/tty
        case "$_shell_resp" in
            1) SHELL_CHOICE="bash"; break ;;
            2) SHELL_CHOICE="zsh";  break ;;
            3) SHELL_CHOICE="none"; break ;;
            *) warn "Opción inválida '$_shell_resp' — introduce 1, 2 o 3" ;;
        esac
    done
}

# ─── 5. Resumen y confirmación ────────────────────────────────────────────────
show_summary() {
    header "Resumen de instalación"

    echo -e "   ${BOLD}Disco          :${NC} ${RED}${BOLD}$TARGET_DISK — TODO EL CONTENIDO SERÁ ELIMINADO${NC}"
    echo -e "   ${BOLD}Hostname       :${NC} $SYS_HOSTNAME"
    echo -e "   ${BOLD}Usuario        :${NC} $USERNAME"
    echo -e "   ${BOLD}Zona horaria   :${NC} $TIMEZONE"
    echo -e "   ${BOLD}Locale         :${NC} $LOCALE"
    echo -e "   ${BOLD}Teclado        :${NC} ${XKB_LAYOUT}${XKB_VARIANT:+ / $XKB_VARIANT}  (vconsole: $KEYMAP)"
    echo -e "   ${BOLD}Cifrado LUKS2  :${NC} $( $USE_LUKS     && echo 'SI' || echo 'NO' )"
    echo -e "   ${BOLD}Hibernación    :${NC} $( $USE_HIBERNATE && echo 'SI' || echo 'NO' )"
    echo -e "   ${BOLD}Swap           :${NC} ${SWAP_SIZE} GB"
    echo -e "   ${BOLD}GPU            :${NC} $GPU_TYPE${EXTRA_KERNEL_PARAMS:+ ($EXTRA_KERNEL_PARAMS)}"
    echo -e "   ${BOLD}Docker subvol  :${NC} $( $USE_DOCKER   && echo 'SI' || echo 'NO' )"
    local _shell_desc="sin cambios (bash)"
    [[ "$SHELL_CHOICE" == "bash" ]] && _shell_desc="Bash mejorado (ble.sh + Oh My Bash)"
    [[ "$SHELL_CHOICE" == "zsh"  ]] && _shell_desc="ZSH con plugins"
    [[ "$SHELL_CHOICE" == "none" ]] && _shell_desc="Ninguno (bash sin modificar)"
    echo -e "   ${BOLD}Shell          :${NC} $_shell_desc"

    echo -e "\n   ${BOLD}Subvolúmenes BTRFS:${NC}"
    info "@            →  /"
    info "@home        →  /home"
    info "@log         →  /var/log"
    info "@snapshots   →  /.snapshots"
    info "@pkg         →  /var/cache/pacman/pkg"
    info "@swap        →  /swap  (${SWAP_SIZE} GB, nodatacow)"
    $USE_DOCKER && info "@docker      →  /var/lib/docker  (nodatacow)"

    echo -e "\n   ${RED}${BOLD}ADVERTENCIA: OPERACIÓN IRREVERSIBLE.${NC}"
    echo -e "   ${RED}Se borrarán TODOS los datos de $TARGET_DISK.${NC}\n"
    confirm "¿Confirmas la instalación?" || die "Instalación cancelada."
}

# ─── 6. Particionado ──────────────────────────────────────────────────────────
partition_disk() {
    step "Particionando $TARGET_DISK..."
    wipefs -af "$TARGET_DISK"
    parted -s "$TARGET_DISK" \
        mklabel gpt \
        mkpart EFI  fat32  1MiB 513MiB \
        set 1 esp on \
        mkpart ROOT btrfs  513MiB 100%
    partprobe "$TARGET_DISK"
    sleep 2

    if [[ "$TARGET_DISK" =~ nvme|mmcblk ]]; then
        EFI_PART="${TARGET_DISK}p1"
        BTRFS_PART="${TARGET_DISK}p2"
    else
        EFI_PART="${TARGET_DISK}1"
        BTRFS_PART="${TARGET_DISK}2"
    fi
    ok "EFI: $EFI_PART (512 MB)"
    ok "BTRFS: $BTRFS_PART (resto del disco)"
}

# ─── 7. LUKS (opcional) ───────────────────────────────────────────────────────
setup_luks() {
    if ! $USE_LUKS; then
        BTRFS_DEV="$BTRFS_PART"
        return
    fi
    step "Configurando cifrado LUKS2..."
    echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks2 \
        --label CRYPTROOT "$BTRFS_PART" -
    echo -n "$LUKS_PASS" | cryptsetup open "$BTRFS_PART" cryptroot -
    BTRFS_DEV="/dev/mapper/cryptroot"
    ok "LUKS2 configurado → $BTRFS_DEV"
}

# ─── 8. Formateo ──────────────────────────────────────────────────────────────
format_partitions() {
    step "Formateando particiones..."
    mkfs.fat -F32 -n EFI "$EFI_PART"
    ok "EFI (vfat): $EFI_PART"
    mkfs.btrfs -f -L CachyOS "$BTRFS_DEV"
    ok "BTRFS (label CachyOS): $BTRFS_DEV"
}

# ─── 9. Subvolúmenes BTRFS ────────────────────────────────────────────────────
create_subvols() {
    step "Creando subvolúmenes BTRFS..."
    mount "$BTRFS_DEV" /mnt

    local subvols=("@" "@home" "@log" "@snapshots" "@pkg" "@swap")
    $USE_DOCKER && subvols+=("@docker")

    for sv in "${subvols[@]}"; do
        btrfs subvolume create "/mnt/$sv"
        ok "Subvolumen: $sv"
    done

    # snapper rollback requiere que @ sea el subvolumen por defecto de BTRFS.
    # Sin esto, "snapper rollback N" falla con "no se conoce el subvolumen por defecto".
    local at_id
    at_id=$(btrfs subvolume list /mnt | awk '$NF=="@"{print $2}')
    btrfs subvolume set-default "$at_id" /mnt
    ok "Subvolumen por defecto: @ (ID $at_id)"

    umount /mnt
}

# ─── 10. Montaje ──────────────────────────────────────────────────────────────
mount_all() {
    step "Montando sistema de archivos..."
    local opts="rw,noatime,compress=zstd:1,space_cache=v2"

    mount -o "${opts},subvol=@" "$BTRFS_DEV" /mnt

    mkdir -p /mnt/{home,var/log,var/cache/pacman/pkg,.snapshots,swap,boot/efi}
    $USE_DOCKER && mkdir -p /mnt/var/lib/docker

    mount -o "${opts},subvol=@home"      "$BTRFS_DEV" /mnt/home
    mount -o "${opts},subvol=@log"       "$BTRFS_DEV" /mnt/var/log
    mount -o "${opts},subvol=@snapshots" "$BTRFS_DEV" /mnt/.snapshots
    mount -o "${opts},subvol=@pkg"       "$BTRFS_DEV" /mnt/var/cache/pacman/pkg
    mount -o "rw,noatime,nodatacow,subvol=@swap" "$BTRFS_DEV" /mnt/swap
    $USE_DOCKER && \
        mount -o "rw,noatime,nodatacow,subvol=@docker" "$BTRFS_DEV" /mnt/var/lib/docker

    mount "$EFI_PART" /mnt/boot/efi
    ok "Sistema montado en /mnt"
}

# ─── 11. Swapfile ─────────────────────────────────────────────────────────────
setup_swap() {
    step "Creando swapfile (${SWAP_SIZE} GB)..."
    btrfs filesystem mkswapfile --size "${SWAP_SIZE}g" /mnt/swap/swapfile
    swapon /mnt/swap/swapfile
    ok "Swapfile activo: /swap/swapfile"

    if $USE_HIBERNATE; then
        SWAP_OFFSET=$(btrfs inspect-internal map-swapfile -r /mnt/swap/swapfile)
        ok "Offset de hibernación: $SWAP_OFFSET"
    fi
}

# ─── 12. Mirrors ──────────────────────────────────────────────────────────────
configure_mirrors() {
    step "Configurando mirrors (puede tardar ~1 minuto)..."
    cachyos-rate-mirrors \
        || die "cachyos-rate-mirrors falló"
    ok "Mirrors configurados"
}

# ─── 13. Instalación base ─────────────────────────────────────────────────────
install_pacstrap() {
    step "Instalando sistema base..."

    local pkgs=(
        base base-devel linux-cachyos linux-cachyos-headers linux-firmware
        btrfs-progs grub grub-btrfs efibootmgr
        networkmanager openssh sudo vim
        snapper snap-pac inotify-tools
        cachyos-keyring cachyos-mirrorlist
        man-db less unzip rsync
    )
    $USE_LUKS && pkgs+=(cryptsetup)

    local attempt=0 max_retries=3
    while (( attempt < max_retries )); do
        (( attempt++ ))
        : > /tmp/pacstrap.log

        if pacstrap -c /mnt "${pkgs[@]}" |& tee /tmp/pacstrap.log; then
            break
        fi

        if grep -qE "returned error: [45][0-9]{2}|failed to retrieve some files" /tmp/pacstrap.log \
                && (( attempt < max_retries )); then
            warn "Error de descarga en intento $attempt/$max_retries — seleccionando mirrors activos (~60 s)..."
            cachyos-rate-mirrors &>/dev/null \
                || warn "cachyos-rate-mirrors falló — continuando con mirrors actuales"
            pacman -Syy --noconfirm &>/dev/null || true
            info "Reintentando (los paquetes ya en caché no se repiten)..."
            continue
        fi

        die "pacstrap falló — revisa /tmp/pacstrap.log"
    done

    [[ -x /mnt/bin/bash ]] \
        || die "/mnt/bin/bash no existe — instalación incompleta"
    ok "Sistema base instalado"
}

# ─── 14. fstab ────────────────────────────────────────────────────────────────
generate_fstab() {
    step "Generando /etc/fstab..."
    genfstab -U /mnt >> /mnt/etc/fstab \
        || die "genfstab falló"
    ok "fstab generado"
}

# ─── 14. Repos CachyOS en el sistema instalado ────────────────────────────────

configure_cachyos_repos() {
    step "Configurando repos CachyOS en el sistema instalado..."

    # El live USB ya tiene el pacman.conf correcto con todos los repos CachyOS
    cp /etc/pacman.conf /mnt/etc/pacman.conf \
        || die "No se pudo copiar /etc/pacman.conf al sistema instalado"

    # Copiar todas las mirrorlists de CachyOS disponibles en el live USB
    for ml in cachyos-mirrorlist cachyos-v3-mirrorlist cachyos-znver4-mirrorlist; do
        [[ -f "/etc/pacman.d/$ml" ]] \
            && cp "/etc/pacman.d/$ml" "/mnt/etc/pacman.d/$ml"
    done

    ok "Repos CachyOS configurados en el sistema instalado"
}

# ─── 15. Configuración en chroot ──────────────────────────────────────────────
configure_chroot() {
    step "Configurando sistema en chroot..."
    [[ -x /mnt/bin/bash ]] \
        || die "/mnt/bin/bash no existe — pacstrap no completó correctamente"

    # UUIDs necesarios para GRUB
    local btrfs_uuid luks_uuid=""
    btrfs_uuid=$(blkid -s UUID -o value "$BTRFS_DEV")
    $USE_LUKS && luks_uuid=$(blkid -s UUID -o value "$BTRFS_PART")

    # Parámetros del kernel para GRUB
    local grub_params="quiet net.ifnames=0 biosdevname=0"
    [[ -n "$EXTRA_KERNEL_PARAMS" ]] && grub_params+=" $EXTRA_KERNEL_PARAMS"
    $USE_LUKS      && grub_params+=" cryptdevice=UUID=${luks_uuid}:cryptroot root=$BTRFS_DEV"
    $USE_HIBERNATE && grub_params+=" resume=UUID=${btrfs_uuid} resume_offset=${SWAP_OFFSET}"

    # Hooks mkinitcpio
    local hooks="base udev autodetect microcode modconf kms keyboard keymap consolefont block"
    $USE_LUKS && hooks+=" encrypt"
    hooks+=" filesystems"
    $USE_HIBERNATE && hooks+=" resume"
    hooks+=" btrfs fsck"

    # /etc/hosts
    cat > /mnt/etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${SYS_HOSTNAME}.localdomain ${SYS_HOSTNAME}
EOF

    # Teclado X11/Wayland — SDDM + Hyprland
    mkdir -p /mnt/etc/X11/xorg.conf.d
    {
        echo 'Section "InputClass"'
        echo '    Identifier "system-keyboard"'
        echo '    MatchIsKeyboard "on"'
        echo "    Option \"XkbLayout\"  \"${XKB_LAYOUT}\""
        [[ -n "$XKB_VARIANT" ]] && echo "    Option \"XkbVariant\" \"${XKB_VARIANT}\""
        echo 'EndSection'
    } > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
    ok "Teclado X11: ${XKB_LAYOUT}${XKB_VARIANT:+/$XKB_VARIANT}"

    # ── Escrituras directas a /mnt — sin chroot, sin expansión problemática ──────

    # Locale
    echo "${LOCALE} UTF-8" >> /mnt/etc/locale.gen
    printf 'LANG=%s\n'   "${LOCALE}" > /mnt/etc/locale.conf
    printf 'KEYMAP=%s\n' "${KEYMAP}" > /mnt/etc/vconsole.conf

    # Zona horaria
    ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /mnt/etc/localtime

    # Hostname
    echo "${SYS_HOSTNAME}" > /mnt/etc/hostname

    # mkinitcpio
    sed -i "s/^MODULES=.*/MODULES=(btrfs)/"  /mnt/etc/mkinitcpio.conf
    sed -i "s/^HOOKS=.*/HOOKS=(${hooks})/"   /mnt/etc/mkinitcpio.conf

    # GRUB — cmdline + cifrado
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${grub_params}\"|" \
        /mnt/etc/default/grub
    $USE_LUKS && echo 'GRUB_ENABLE_CRYPTODISK=y' >> /mnt/etc/default/grub

    # GRUB — cosmética (modo gráfico, distribuidor, timeout)
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="CachyOS"/' /mnt/etc/default/grub

    sed -i 's/^#\?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE="menu"/' /mnt/etc/default/grub
    grep -q '^GRUB_TIMEOUT_STYLE=' /mnt/etc/default/grub \
        || echo 'GRUB_TIMEOUT_STYLE="menu"' >> /mnt/etc/default/grub

    sed -i 's/^#\?GRUB_TERMINAL_OUTPUT=.*/GRUB_TERMINAL_OUTPUT="gfxterm"/' /mnt/etc/default/grub
    grep -q '^GRUB_TERMINAL_OUTPUT=' /mnt/etc/default/grub \
        || echo 'GRUB_TERMINAL_OUTPUT="gfxterm"' >> /mnt/etc/default/grub

    sed -i 's/^#\?GRUB_GFXMODE=.*/GRUB_GFXMODE="auto"/' /mnt/etc/default/grub
    grep -q '^GRUB_GFXMODE=' /mnt/etc/default/grub \
        || echo 'GRUB_GFXMODE="auto"' >> /mnt/etc/default/grub

    sed -i 's/^#\?GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX="keep"/' /mnt/etc/default/grub
    grep -q '^GRUB_GFXPAYLOAD_LINUX=' /mnt/etc/default/grub \
        || echo 'GRUB_GFXPAYLOAD_LINUX="keep"' >> /mnt/etc/default/grub

    mkdir -p /mnt/boot/grub/fonts
    cp /usr/share/grub/unicode.pf2 /mnt/boot/grub/fonts/unicode.pf2 2>/dev/null || true
    grep -q '^GRUB_FONT=' /mnt/etc/default/grub \
        || echo 'GRUB_FONT="/boot/grub/fonts/unicode.pf2"' >> /mnt/etc/default/grub

    # grub-btrfs — nombre del submenú de snapshots
    sed -i 's|^#\?GRUB_BTRFS_SUBMENUNAME=.*|GRUB_BTRFS_SUBMENUNAME="CachyOS Linux Snapshots"|' \
        /mnt/etc/default/grub-btrfs/config

    # sudo
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers

    # ── Comandos que DEBEN correr en el chroot — heredoc QUOTED (sin expansión externa) ──

    arch-chroot /mnt /bin/bash -s << 'CHROOT' || die "La configuración en chroot falló"
set -e
trap 'echo "  ERROR en: $BASH_COMMAND" >&2' ERR

locale-gen
hwclock --systohc
mkinitcpio -P

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=CachyOS --recheck \
    || grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=CachyOS --removable

grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

    # ── Usuario — arch-chroot separado para usar variables del shell externo ───
    arch-chroot /mnt useradd -m -G wheel,audio,video,storage,optical \
        -s /bin/bash "${USERNAME}" \
        || die "Error al crear el usuario ${USERNAME}"
    arch-chroot /mnt passwd -l root \
        || die "Error al bloquear la cuenta root"
    ok "Usuario ${USERNAME} creado"

    # Snapper config — escrita desde el host para evitar el conflicto con @snapshots
    # montado en /.snapshots (snapper create-config intentaría crear ese subvol → errno 17).
    # El template puede no existir en el chroot; lo generamos directamente.
    mkdir -p /mnt/etc/snapper/configs
    cat > /mnt/etc/snapper/configs/root << 'SNAPPER_CFG'
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
SNAPPER_CFG
    chmod 640 /mnt/etc/snapper/configs/root
    chmod 750 /mnt/.snapshots
    ok "Config snapper creada"
    # /etc/conf.d/snapper viene del paquete con SNAPPER_CONFIGS="" — snapperd y
    # snap-pac leen esta variable para saber qué configs gestionar. Sin esto,
    # snapperd no carga "root" (sudo snapper list falla) y snap-pac no crea
    # snapshots pre/post en cada pacman/paru.
    sed -i 's/^SNAPPER_CONFIGS=.*/SNAPPER_CONFIGS="root"/' /mnt/etc/conf.d/snapper
    ok "SNAPPER_CONFIGS=root configurado (snap-pac y snapperd activos)"

    # Servicios — systemctl enable --root nunca toca DBus, solo crea symlinks
    systemctl enable --root=/mnt NetworkManager sshd
    systemctl enable --root=/mnt snapper-timeline.timer snapper-cleanup.timer
    systemctl enable --root=/mnt grub-btrfsd.service 2>/dev/null \
        || systemctl enable --root=/mnt grub-btrfs.path 2>/dev/null \
        || true

    # Contraseña — archivo temporal con 600 para manejar cualquier carácter especial
    local creds_tmp="/mnt/root/.install_creds"
    printf '%s:%s\n' "${USERNAME}" "${USERPASS}" > "$creds_tmp"
    chmod 600 "$creds_tmp"
    arch-chroot /mnt /bin/bash -c "chpasswd < /root/.install_creds && rm /root/.install_creds" \
        || die "Error al establecer la contraseña de ${USERNAME}"
    ok "Contraseña de $USERNAME establecida"

    ok "Configuración en chroot completada"
}

# ─── 16. Mejora del shell ─────────────────────────────────────────────────────
install_shell_enhancement() {
    [[ "$SHELL_CHOICE" == "none" ]] && return

    if [[ "$SHELL_CHOICE" == "zsh" ]]; then
        step "Instalando ZSH + Oh My Zsh..."
        arch-chroot /mnt pacman -S --needed --noconfirm zsh zsh-syntax-highlighting zsh-autosuggestions curl git
        ok "Paquetes ZSH instalados"

        # Resolver la ruta real del binario dentro del chroot (no hardcodear)
        local zsh_path
        zsh_path=$(arch-chroot /mnt /bin/bash -c 'command -v zsh' 2>/dev/null)
        [[ -n "$zsh_path" ]] || die "zsh no se instaló correctamente — binario no encontrado en el chroot"

        # chsh exige que el shell esté en /etc/shells; añadirlo si falta (idempotente)
        if ! grep -qx "$zsh_path" /mnt/etc/shells 2>/dev/null; then
            echo "$zsh_path" >> /mnt/etc/shells
            ok "$zsh_path añadido a /etc/shells"
        fi

        arch-chroot /mnt chsh -s "$zsh_path" "$USERNAME" \
            || die "No se pudo cambiar el shell de $USERNAME a zsh"

        # Verificar que el cambio quedó aplicado (evita falso positivo)
        arch-chroot /mnt getent passwd "$USERNAME" | grep -q ":${zsh_path}$" \
            || die "El shell de $USERNAME no quedó como $zsh_path — revisa la cuenta antes de reiniciar"
        ok "Shell por defecto cambiado a ZSH ($zsh_path)"

        # Script temporal ejecutado como usuario dentro del chroot
        local _zscript="/mnt/home/$USERNAME/setup_omz.sh"
        cat > "$_zscript" << 'ZSCRIPT'
#!/bin/bash
set -e
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    [[ -d "$HOME/.oh-my-zsh" ]] || { echo "ERROR: oh-my-zsh no se instaló" >&2; exit 1; }
fi

zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
mkdir -p "$zsh_custom/plugins"
for plugin in zsh-syntax-highlighting zsh-autosuggestions; do
    sys_path="/usr/share/zsh/plugins/$plugin"
    dst="$zsh_custom/plugins/$plugin"
    [[ -e "$dst" ]] || ( [[ -d "$sys_path" ]] && ln -sf "$sys_path" "$dst" )
done

if ! grep -q 'ZSH_THEME="bira"' "$HOME/.zshrc" 2>/dev/null; then
    cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
# Fix TERM para sesiones SSH sin terminfo del emulador local
if [[ -n "$SSH_CONNECTION" ]] && ! infocmp "$TERM" &>/dev/null; then
  export TERM=xterm-256color
fi

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="bira"

plugins=(git zsh-syntax-highlighting zsh-autosuggestions docker-compose gcloud python)

source $ZSH/oh-my-zsh.sh

export PATH="$HOME/.local/bin:$PATH"

# Fix backspace/delete para terminales modernas (Alacritty)
bindkey "^?" backward-delete-char
bindkey "^H" backward-delete-char
bindkey "^[[3~" delete-char
ZSHRC_EOF
fi
ZSCRIPT
        chmod +x "$_zscript"
        arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/setup_omz.sh"
        arch-chroot /mnt /bin/su -l "$USERNAME" -s /bin/bash -c "/home/$USERNAME/setup_omz.sh" \
            || die "Error instalando Oh My Zsh como usuario $USERNAME"
        rm -f "$_zscript"
        ok "Oh My Zsh instalado — tema bira + plugins (git, zsh-syntax-highlighting, zsh-autosuggestions, docker-compose, gcloud, python)"
    fi

    if [[ "$SHELL_CHOICE" == "bash" ]]; then
        step "Instalando Super Bash (ble.sh + Oh My Bash)..."
        arch-chroot /mnt pacman -S --needed --noconfirm git make curl
        ok "Dependencias instaladas (git, make, curl)"

        # Script temporal ejecutado como usuario dentro del chroot.
        # Se escribe en $HOME del usuario (garantizado que existe); /tmp dentro del
        # chroot puede no estar montado si el sistema usa tmpfs en fstab.
        local _bscript="/mnt/home/$USERNAME/install_bash_user.sh"
        cat > "$_bscript" << 'USERSCRIPT'
#!/bin/bash
set -e
if [[ ! -f "$HOME/.local/share/blesh/ble.sh" ]]; then
    git clone --recursive --depth=1 https://github.com/akinomyoga/ble.sh.git "$HOME/.cache/blesh_build"
    make -C "$HOME/.cache/blesh_build" install PREFIX="$HOME/.local"
    rm -rf "$HOME/.cache/blesh_build"
fi
if [[ ! -d "$HOME/.oh-my-bash" ]]; then
    # --unattended: evita que install.sh termine con "exec bash", que reemplazaría
    # el proceso y dejaría un shell interactivo colgado sin TTY en el chroot.
    # RUNBASH/CHSH/KEEP_BASHRC son de Oh My Zsh; OMB las ignora por completo.
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended
    [[ -d "$HOME/.oh-my-bash" ]] || { echo "ERROR: oh-my-bash no se instaló" >&2; exit 1; }
fi
USERSCRIPT
        chmod +x "$_bscript"
        arch-chroot /mnt /bin/su -l "$USERNAME" -s /bin/bash -c "/home/$USERNAME/install_bash_user.sh" \
            || die "Error instalando Super Bash como usuario $USERNAME"
        rm -f "$_bscript"
        ok "ble.sh y Oh My Bash instalados"

        # Integrar ble.sh en ~/.bashrc (prepend + append) desde el host
        local bashrc="/mnt/home/$USERNAME/.bashrc"
        [[ ! -f "$bashrc" ]] && touch "$bashrc"
        if ! grep -q 'ble.sh --noattach' "$bashrc"; then
            local content
            content=$(cat "$bashrc")
            {
                printf '%s\n' '# Fix TERM para sesiones SSH sin terminfo del emulador local'
                printf '%s\n' 'if [[ -n "$SSH_CONNECTION" ]] && ! infocmp "$TERM" &>/dev/null 2>&1; then'
                printf '%s\n' '  export TERM=xterm-256color'
                printf '%s\n\n' 'fi'
                printf '%s\n\n' '[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --noattach 2>/dev/null'
                printf '%s\n' "$content"
                printf '%s\n' '[[ ${BLE_VERSION-} ]] && ble-attach'
            } > "${bashrc}.new"
            mv "${bashrc}.new" "$bashrc"
            arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/.bashrc"
            ok "ble.sh integrado en ~/.bashrc"
        else
            ok "ble.sh ya presente en ~/.bashrc"
        fi
    fi

    info "Shell mejorado activo en el primer inicio de sesión"
}

# ─── 15. Helper de Rollback Btrfs ─────────────────────────────────────────────
install_rollback_helper() {
    step "Instalando helper btrfs-rollback..."

    # Script que se copia a /usr/local/bin dentro del chroot
    cat > /mnt/usr/local/bin/btrfs-rollback << 'ROLLBACK_SCRIPT'
#!/bin/bash
set -euo pipefail

# Helper CLI para rollback de Btrfs usando snapshots de snapper
# Uso: sudo btrfs-rollback <N>

[[ $EUID -ne 0 ]] && { echo "ERROR: requiere root (usar sudo)" >&2; exit 1; }
[[ $# -ne 1 || ! $1 =~ ^[0-9]+$ ]] && { echo "Uso: $0 <numero_snapshot>" >&2; exit 1; }

SNAP_NUM="$1"
BTRFS_DEV=$(findmnt -n -o SOURCE --target / | sed 's/\[.*\]//')
[[ -z "$BTRFS_DEV" ]] && { echo "ERROR: no se detectó device Btrfs" >&2; exit 1; }

TMPDIR=$(mktemp -d)
trap "umount '$TMPDIR' 2>/dev/null || true; rmdir '$TMPDIR' 2>/dev/null || true" EXIT

mount -o subvolid=5 "$BTRFS_DEV" "$TMPDIR"

# Validar snapshot — snapshots están en @snapshots/N/snapshot (subvolume, no punto de montaje)
if [[ ! -d "$TMPDIR/@snapshots/$SNAP_NUM/snapshot" ]]; then
    echo "ERROR: snapshot $SNAP_NUM no existe" >&2
    echo "Snapshots disponibles:"
    btrfs subvolume list "$TMPDIR" | grep "@snapshots" | awk '{print $NF}' | grep snapshot | sed 's|@snapshots/||;s|/snapshot||' | sort -V | sed 's|^|  |'
    exit 1
fi

echo "Snapshots disponibles:"
btrfs subvolume list "$TMPDIR" | grep "@snapshots" | awk '{print $NF}' | grep snapshot | sed 's|@snapshots/||;s|/snapshot||' | sort -V | sed 's|^|  |'
echo ""
echo "Restaurando desde snapshot $SNAP_NUM..."
read -p "¿Continuar? (s/N) " -r CONFIRM
[[ "$CONFIRM" =~ ^[sS]$ ]] || { echo "Abortado"; exit 0; }

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
[[ -d "$TMPDIR/@" ]] && mv "$TMPDIR/@" "$TMPDIR/@_old_$TIMESTAMP" && echo "  Backup: @_old_$TIMESTAMP"

btrfs subvolume snapshot "$TMPDIR/@snapshots/$SNAP_NUM/snapshot" "$TMPDIR/@" && echo "  Snapshot restaurado a @"

NEW_ID=$(btrfs subvolume list "$TMPDIR" | awk '$NF=="@" {print $2}')
btrfs subvolume set-default "$NEW_ID" "$TMPDIR" && echo "  Default subvolume: @ (ID $NEW_ID)"

echo ""
echo "✓ Rollback completado. Ejecuta: sudo reboot"
ROLLBACK_SCRIPT

    chmod 755 /mnt/usr/local/bin/btrfs-rollback
    ok "Helper btrfs-rollback instalado en /usr/local/bin"
}

# ─── 16. Snapshot inicial ─────────────────────────────────────────────────────
take_snapshot() {
    step "Creando snapshot inicial..."
    arch-chroot /mnt snapper --no-dbus -c root create --description "sistema-base-instalado" \
        || die "Error creando snapshot inicial"
    ok "Snapshot inicial creado"
}

# ─── 18. Desmontaje ───────────────────────────────────────────────────────────
unmount_all() {
    step "Desmontando..."
    swapoff /mnt/swap/swapfile 2>/dev/null || true
    umount -R /mnt
    $USE_LUKS && cryptsetup close cryptroot 2>/dev/null || true
    ok "Desmontado correctamente"
}

# ─── 19. Resumen final ────────────────────────────────────────────────────────
final_summary() {
    header "Instalacion base completada"

    local _shell_desc="sin cambios (bash)"
    [[ "$SHELL_CHOICE" == "bash" ]] && _shell_desc="Bash mejorado (ble.sh + Oh My Bash)"
    [[ "$SHELL_CHOICE" == "zsh"  ]] && _shell_desc="ZSH con plugins"
    [[ "$SHELL_CHOICE" == "none" ]] && _shell_desc="Ninguno (bash sin modificar)"

    echo -e "\n   ${BOLD}Configuración aplicada:${NC}"
    echo -e "   ${BOLD}Disco          :${NC} $TARGET_DISK"
    echo -e "   ${BOLD}Hostname       :${NC} $SYS_HOSTNAME"
    echo -e "   ${BOLD}Usuario        :${NC} $USERNAME (sudo via wheel)"
    echo -e "   ${BOLD}Shell          :${NC} $_shell_desc"
    echo -e "   ${BOLD}Zona horaria   :${NC} $TIMEZONE"
    echo -e "   ${BOLD}Locale         :${NC} $LOCALE"
    echo -e "   ${BOLD}Teclado        :${NC} ${XKB_LAYOUT}${XKB_VARIANT:+ / $XKB_VARIANT}  (vconsole: $KEYMAP)"
    echo -e "   ${BOLD}GPU            :${NC} $GPU_TYPE${EXTRA_KERNEL_PARAMS:+ ($EXTRA_KERNEL_PARAMS)}"
    echo -e "   ${BOLD}Cifrado LUKS2  :${NC} $( $USE_LUKS      && echo 'SI' || echo 'NO' )"
    echo -e "   ${BOLD}Hibernación    :${NC} $( $USE_HIBERNATE && echo "SI (swap offset: $SWAP_OFFSET)" || echo 'NO' )"
    echo -e "   ${BOLD}Swap           :${NC} ${SWAP_SIZE} GB"
    echo -e "   ${BOLD}Docker subvol  :${NC} $( $USE_DOCKER    && echo 'SI' || echo 'NO' )"
    echo -e "   ${BOLD}GRUB           :${NC} snapper + grub-btrfs"

    echo -e "\n   ${BOLD}Subvolúmenes BTRFS:${NC}"
    info "@            →  /"
    info "@home        →  /home"
    info "@log         →  /var/log"
    info "@snapshots   →  /.snapshots"
    info "@pkg         →  /var/cache/pacman/pkg"
    info "@swap        →  /swap  (${SWAP_SIZE} GB, nodatacow)"
    $USE_DOCKER && info "@docker      →  /var/lib/docker  (nodatacow)"

    $USE_LUKS && echo -e "\n   ${YELLOW}${BOLD}⚠  No pierdas la passphrase LUKS — sin ella el disco es irrecuperable.${NC}"

    echo -e "\n   ${BOLD}Proximos pasos:${NC}"
    info "1. Retira el USB y reinicia el equipo:"
    echo -e "\n      ${BOLD}reboot${NC}\n"
    info "2. Inicia sesion como $USERNAME y valida snapper (requiere systemd):"
    echo -e "\n      ${BOLD}sudo snapper -c root list${NC}\n"
    info "   Debes ver el snapshot 'sistema-base-instalado'. Luego instala cualquier"
    info "   paquete y confirma que snap-pac crea snapshots pre/post automaticamente:"
    echo -e "\n      ${BOLD}sudo pacman -S --noconfirm sl${NC}"
    echo -e "      ${BOLD}sudo snapper -c root list${NC}\n"
    info "3. Para hacer rollback a un snapshot anterior (si algo se rompe):"
    echo -e "\n      ${BOLD}sudo btrfs-rollback <N>${NC}"
    echo -e "      ${BOLD}sudo reboot${NC}\n"
    info "4. Si solo usaras el equipo en TTY/SSH (sin escritorio), el sistema esta listo."
    info "   Si quieres Hyprland, copia install-cachyos-hyprland.sh y ejecuta:"
    echo -e "\n      ${BOLD}bash install-cachyos-hyprland.sh${NC}\n"
    info "5. Tras reiniciar en Hyprland, ejecuta:"
    echo -e "\n      ${BOLD}bash install-hyprland-desktop.sh${NC}\n"
}

# ─── Limpieza de montajes previos ─────────────────────────────────────────────
# Si el script se re-ejecuta sin reiniciar (fallo a mitad), /mnt queda montado.
# grub-install dentro del chroot falla si el EFI está montado en doble capa.
initial_cleanup() {
    if mountpoint -q /mnt 2>/dev/null; then
        warn "Detectados montajes previos en /mnt — limpiando antes de continuar..."
        swapoff /mnt/swap/swapfile 2>/dev/null || true
        umount -R /mnt 2>/dev/null || true
        cryptsetup close cryptroot 2>/dev/null || true
        ok "Montajes anteriores desmontados"
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────
header "Instalador base CachyOS"
echo -e "   ${DIM}BTRFS + subvolumenes + pacstrap + GRUB + snapper — Caps 1-10${NC}"

check_prereqs
initial_cleanup
detect_gpu
detect_ram
ask_questions
show_summary
partition_disk
setup_luks
format_partitions
create_subvols
mount_all
setup_swap
configure_mirrors
install_pacstrap
generate_fstab
configure_cachyos_repos
configure_chroot
install_shell_enhancement
install_rollback_helper
take_snapshot
unmount_all
final_summary
