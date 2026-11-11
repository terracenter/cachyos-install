#!/usr/bin/env bash
# Las preguntas del asistente se invocan por nombre desde WIZARD_STEPS: shellcheck no ve esas llamadas.
# shellcheck disable=SC2317,SC2329
export NCURSES_NO_UTF8_ACS=1
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
BLUE='\033[0;34m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

# ─── Trap de error inesperado ─────────────────────────────────────────────────
# Invocada indirectamente por el trap ERR.
# shellcheck disable=SC2329
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

# Ejecuta whiptail con el botón Atrás y deja la respuesta en WT_OUT.
# Retorna 0 al aceptar y 1 con Atrás. Esc pregunta si se sale del instalador;
# si no se sale, repite la misma pantalla. Nunca asigna ningún valor.
wt() {
    local rc
    while true; do
        if WT_OUT=$(whiptail --backtitle "$BACKTITLE" --cancel-button "Atrás" "$@" 3>&1 1>&2 2>&3); then
            return 0
        else
            rc=$?
        fi
        if [[ $rc -eq 255 ]]; then
            confirm_exit
        else
            return 1
        fi
    done
}

confirm_exit() {
    if whiptail --title "Salir" --backtitle "$BACKTITLE" --defaultno --yes-button "Sí" --no-button "No" --yesno "¿Salir del instalador?" 8 50; then
        die "Instalación cancelada."
    fi
}

# La pregunta en curso ya se respondió antes (se volvió a ella con Atrás o desde el resumen).
answered() { [[ -n "${STEP_OK[$CURRENT_STEP]:-}" ]]; }

# $1 = texto, $2 = variable, $3 = valor inicial. Asigna la variable solo si el usuario acepta.
ask() {
    local prompt="$1" var="$2" default="${3:-}"
    wt --title "Entrada Requerida" --inputbox "$prompt" 10 60 "$default" || return 1
    printf -v "$var" '%s' "$WT_OUT"
}

# Pregunta Sí/No como menú, para que lleve el botón Atrás. $2 = variable (true|false).
# La primera vez propone Sí; si la pregunta ya se respondió (o $3 no está vacío), marca la respuesta dada.
ask_yesno() {
    local prompt="$1" var="$2" item="si"
    if { answered || [[ -n "${3:-}" ]]; } && [[ "${!var}" == "false" ]]; then item="no"; fi
    wt --title "Pregunta" --default-item "$item" --menu "$prompt" 12 70 2 "si" "Sí" "no" "No" || return 1
    if [[ "$WT_OUT" == "si" ]]; then
        printf -v "$var" '%s' true
    else
        printf -v "$var" '%s' false
    fi
}

ask_number() {
    local prompt="$1" var="$2" default="${3:-}"
    while true; do
        wt --title "Número Requerido" --inputbox "$prompt" 10 60 "$default" || return 1
        if [[ -z "$WT_OUT" && -n "$default" ]]; then
            printf -v "$var" '%s' "$default"
            return 0
        fi
        if [[ "$WT_OUT" =~ ^[0-9]+$ ]] && (( WT_OUT >= 1 )); then
            printf -v "$var" '%s' "$WT_OUT"
            return 0
        fi
        whiptail --title "Error" --msgbox "Entrada inválida — escribe un número válido." 8 50
    done
}

# $1 = texto, $2 = variable. Si la variable ya tiene valor, dejar el campo vacío lo conserva.
askpass() {
    local prompt="$1" var="$2" pass1 pass2 hint=""
    if [[ -n "${!var}" ]]; then hint=" (vacío = conservar la actual)"; fi
    while true; do
        wt --title "Contraseña" --passwordbox "${prompt}${hint}" 10 60 || return 1
        pass1="$WT_OUT"
        if [[ -z "$pass1" && -n "${!var}" ]]; then
            return 0
        fi
        wt --title "Confirmar Contraseña" --passwordbox "Confirma: $prompt" 10 60 || continue
        pass2="$WT_OUT"
        if [[ "$pass1" == "$pass2" ]]; then
            printf -v "$var" '%s' "$pass1"
            return 0
        fi
        whiptail --title "Error" --msgbox "Las contraseñas no coinciden. Intenta de nuevo." 8 60
    done
}

# $1 = texto; $2 (opcional) = --defaultno, para que «No» sea el botón marcado por defecto.
confirm() {
    if whiptail --title "Confirmación" ${2:+"$2"} --yesno "$1" 12 66; then
        return 0
    else
        return 1
    fi
}

# ─── Variables globales ───────────────────────────────────────────────────────
TARGET_DISK=""
EFI_PART=""
BTRFS_PART=""
BTRFS_DEV=""        # = BTRFS_PART, o /dev/mapper/cryptroot si LUKS

SYS_HOSTNAME=""
USERNAME=""
FULLNAME=""
USERPASS=""
TIMEZONE="America/Caracas"
TZ_DETECTED=""        # zona horaria detectada por IP; vacía si no se pudo detectar
COUNTRY_DETECTED=""   # país detectado por IP (dos letras mayúsculas); vacío si no se pudo detectar
TZ_DETECT_DONE=false  # la consulta a ipinfo.io se hace una sola vez
LOCALE="es_VE.UTF-8"
KEYMAP="us"        # vconsole (/etc/vconsole.conf)
XKB_LAYOUT="us"   # X11/Wayland (SDDM + Hyprland)
XKB_VARIANT=""

USE_LUKS=false
LUKS_PASS=""
USE_HIBERNATE=false
USE_DOCKER=false
SHELL_CHOICE="none"
REPO_URL="https://github.com/terracenter/cachyos-install.git"
REPO_CLONED=false   # true cuando el repositorio quedó descargado en la carpeta del usuario

SWAP_SIZE=4
RAM_GB=0
GPU_TYPE=""
EXTRA_KERNEL_PARAMS=""
SWAP_OFFSET=0

# Asistente de preguntas: botón Atrás, Esc para salir y resumen con acceso directo.
BACKTITLE="Instalador base CachyOS — Esc = salir"
WT_OUT=""           # respuesta de la última pantalla de whiptail
CURRENT_STEP=""     # pregunta en curso
declare -A STEP_OK=()  # preguntas ya respondidas (para marcar su valor al volver a ellas)
WIZARD_STEPS=(step_disk step_hostname step_username step_fullname step_userpass
              ask_timezone ask_locale ask_keyboard step_luks step_swap step_docker step_shell)

# ─── 1. Verificaciones previas ────────────────────────────────────────────────
check_prereqs() {
    header "Verificando requisitos"

    [[ $EUID -eq 0 ]] || die "Ejecuta el script como root: sudo bash install-base.sh"
    ok "Ejecutando como root"

    # Bloqueo estricto anti-legacy BIOS
    if [[ ! -d /sys/firmware/efi/efivars ]]; then
        die "El sistema NO arrancó en modo UEFI. Reinicia y configura tu BIOS/Boot Menu en modo UEFI nativo."
    fi
    ok "Modo UEFI detectado"

    # Arreglo de teclado para la sesión Live ISO (evita caracteres raros)
    loadkeys la-latin1 2>/dev/null || loadkeys es 2>/dev/null || true
    ok "Teclado en español cargado para la sesión Live"


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
        elif [[ $RAM_GB -le 8 ]];  then echo "$RAM_GB"
        elif [[ $RAM_GB -le 64 ]]; then echo 16
        else echo 8; fi
    fi
}

# ─── Selección de zona horaria ───────────────────────────────────────────────
# Consulta una sola vez a ipinfo.io para recomendar la zona y el idioma: la IP pública sale hacia ese servicio.
# Lee solo "timezone" y "country". Deja TZ_DETECTED y COUNTRY_DETECTED vacías si no hay curl, no hay respuesta
# o el valor no tiene el formato esperado (zona IANA; dos letras mayúsculas).
# No guarda la respuesta, no reintenta y nunca detiene el asistente.
detect_timezone() {
    local json tz cc
    TZ_DETECT_DONE=true
    TZ_DETECTED=""
    COUNTRY_DETECTED=""
    command -v curl &>/dev/null || return 0
    json=$(curl -fs --max-time 5 https://ipinfo.io/json 2>/dev/null) || return 0
    tz=$(printf '%s\n' "$json" | sed -n 's/.*"timezone"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
    if [[ $tz =~ ^[A-Za-z_]+(/[A-Za-z0-9_+-]+)+$ ]]; then TZ_DETECTED="$tz"; fi
    cc=$(printf '%s\n' "$json" | sed -n 's/.*"country"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
    if [[ $cc =~ ^[[:upper:]]{2}$ ]]; then COUNTRY_DETECTED="$cc"; fi
    return 0
}

ask_timezone() {
    $TZ_DETECT_DONE || detect_timezone
    local zones
    mapfile -t zones < <(timedatectl list-timezones 2>/dev/null)
    if [[ ${#zones[@]} -gt 0 ]]; then
        local tz_opts=() rec="" z
        for z in "${zones[@]}"; do
            if [[ -n "$TZ_DETECTED" && "$z" == "$TZ_DETECTED" ]]; then
                tz_opts+=("$z" "(Recomendada)")
                rec="$z"
            else
                tz_opts+=("$z" "")
            fi
        done
        local def=() msg="Selecciona tu zona horaria (no se pudo detectar por IP):"
        if [[ -n "$rec" ]]; then msg="Selecciona tu zona horaria (Recomendada = detectada por IP):"; fi
        if answered; then
            def=(--default-item "$TIMEZONE")
        elif [[ -n "$rec" ]]; then
            def=(--default-item "$rec")
        fi
        wt --title "Zona Horaria" "${def[@]}" --menu "$msg" 20 70 12 "${tz_opts[@]}" || return 1
        TIMEZONE="$WT_OUT"
    else
        local init="$TIMEZONE"
        if ! answered && [[ -n "$TZ_DETECTED" ]]; then init="$TZ_DETECTED"; fi
        ask "Zona horaria (ej: America/Caracas)" TIMEZONE "$init" || return 1
    fi
    return 0
}


# ─── Selección de locale ──────────────────────────────────────────────────────
# La recomendación es el idioma de la lista cuyo nombre termina en _<país>.UTF-8, con el país que devuelve ipinfo.
ask_locale() {
    $TZ_DETECT_DONE || detect_timezone
    local def=() cur=9 rec=0 i loc msg
    local locs=(es_VE.UTF-8 es_ES.UTF-8 es_MX.UTF-8 es_AR.UTF-8 es_CO.UTF-8 es_CL.UTF-8 en_US.UTF-8 en_GB.UTF-8)
    local names=("Español Venezuela" "Español España" "Español México" "Español Argentina" "Español Colombia" "Español Chile" "Inglés EE.UU." "Inglés Reino Unido")
    local labels=()
    for i in "${!locs[@]}"; do
        loc="${locs[$i]}"
        labels+=("$loc (${names[$i]})")
        if [[ -n "$COUNTRY_DETECTED" && "$loc" == *_"$COUNTRY_DETECTED".UTF-8 ]]; then
            labels[i]="$loc (${names[$i]}) (Recomendada)"
            rec=$((i + 1))
        fi
        if [[ "$loc" == "$LOCALE" ]]; then cur=$((i + 1)); fi
    done
    if (( rec > 0 )); then
        msg="Selecciona el idioma del sistema (Recomendada = país por IP):"
    elif [[ -n "$COUNTRY_DETECTED" ]]; then
        msg="Selecciona el idioma del sistema (sin recomendación):"
    else
        msg="Selecciona el idioma del sistema (no se pudo detectar por IP):"
    fi
    if answered; then
        def=(--default-item "$cur")
    elif (( rec > 0 )); then
        def=(--default-item "$rec")
    fi
    wt --title "Locale del Sistema" "${def[@]}" --menu "$msg" 20 70 12 \
        "1" "${labels[0]}" \
        "2" "${labels[1]}" \
        "3" "${labels[2]}" \
        "4" "${labels[3]}" \
        "5" "${labels[4]}" \
        "6" "${labels[5]}" \
        "7" "${labels[6]}" \
        "8" "${labels[7]}" \
        "9" "Otro (entrada manual)" || return 1
    
    case "$WT_OUT" in
        1) LOCALE="es_VE.UTF-8" ;;
        2) LOCALE="es_ES.UTF-8" ;;
        3) LOCALE="es_MX.UTF-8" ;;
        4) LOCALE="es_AR.UTF-8" ;;
        5) LOCALE="es_CO.UTF-8" ;;
        6) LOCALE="es_CL.UTF-8" ;;
        7) LOCALE="en_US.UTF-8" ;;
        8) LOCALE="en_GB.UTF-8" ;;
        9) ask "Locale manual (ej: es_PE.UTF-8)" LOCALE "$LOCALE" || { ask_locale; return $?; } ;;
    esac
    return 0
}


# ─── Selección de teclado ────────────────────────────────────────────────────
# La recomendación sale del idioma elegido (LOCALE, con la forma idioma_PAÍS): si el país coincide con una distribución
# de la lista (us, es, fr, de, pt) se recomienda esa; si el idioma es español y el país no es España, se recomienda latam.
ask_keyboard() {
    local def=() cur=8 rec=0 km xl xv lang cc msg
    local labels=("us (Inglés estándar, sin acentos)" "us / intl (Inglés internacional con teclas muertas)" "es (Español España)" "latam (Latinoamérica)" "fr (Francés)" "de (Alemán)" "pt (Portugués)")
    if [[ $LOCALE =~ ^([a-z]{2,3})_([A-Z]{2})([.@]|$) ]]; then
        lang="${BASH_REMATCH[1]}"
        cc="${BASH_REMATCH[2]}"
        case "$cc" in
            US) rec=1 ;;
            ES) rec=3 ;;
            FR) rec=5 ;;
            DE) rec=6 ;;
            PT) rec=7 ;;
            *)  if [[ $lang == es ]]; then rec=4; fi ;;
        esac
    fi
    if (( rec > 0 )); then
        labels[rec-1]+=" (Recomendada)"
        msg="Selecciona el mapa de teclado (Recomendada = según el idioma elegido):"
    else
        msg="Selecciona el mapa de teclado (sin recomendación para este idioma):"
    fi
    if answered; then
        case "${KEYMAP}|${XKB_LAYOUT}|${XKB_VARIANT}" in
            "us|us|")           cur=1 ;;
            "us|us|intl")       cur=2 ;;
            "es|es|")           cur=3 ;;
            "la-latin1|latam|") cur=4 ;;
            "fr|fr|")           cur=5 ;;
            "de|de|")           cur=6 ;;
            "pt-latin1|pt|")    cur=7 ;;
        esac
        def=(--default-item "$cur")
    elif (( rec > 0 )); then
        def=(--default-item "$rec")
    fi
    wt --title "Distribución de Teclado" "${def[@]}" --menu "$msg" 20 80 12 \
        "1" "${labels[0]}" \
        "2" "${labels[1]}" \
        "3" "${labels[2]}" \
        "4" "${labels[3]}" \
        "5" "${labels[4]}" \
        "6" "${labels[5]}" \
        "7" "${labels[6]}" \
        "8" "Otro (entrada manual)" || return 1
    
    case "$WT_OUT" in
        1) KEYMAP="us";         XKB_LAYOUT="us";    XKB_VARIANT="" ;;
        2) KEYMAP="us";         XKB_LAYOUT="us";    XKB_VARIANT="intl" ;;
        3) KEYMAP="es";         XKB_LAYOUT="es";    XKB_VARIANT="" ;;
        4) KEYMAP="la-latin1";  XKB_LAYOUT="latam"; XKB_VARIANT="" ;;
        5) KEYMAP="fr";         XKB_LAYOUT="fr";    XKB_VARIANT="" ;;
        6) KEYMAP="de";         XKB_LAYOUT="de";    XKB_VARIANT="" ;;
        7) KEYMAP="pt-latin1";  XKB_LAYOUT="pt";    XKB_VARIANT="" ;;
        8) 
            km="$KEYMAP"; xl="$XKB_LAYOUT"; xv="$XKB_VARIANT"
            ask "vconsole keymap (ej: us, es)" km "$km" || { ask_keyboard; return $?; }
            if ! answered; then xl="$km"; fi
            ask "XKB layout (ej: us, latam)" xl "$xl" || { ask_keyboard; return $?; }
            ask "XKB variant (ej: intl, vacío si no aplica)" xv "$xv" || { ask_keyboard; return $?; }
            KEYMAP="$km"; XKB_LAYOUT="$xl"; XKB_VARIANT="$xv"
            ;;
    esac
    return 0
}


# ─── 4. Preguntas al usuario ──────────────────────────────────────────────────
# Recorre las preguntas en orden. Aceptar avanza y Atrás retrocede una; Atrás en la primera
# pregunta pide confirmar la salida. $1 = índice inicial. Con $2 se repite solo esa pregunta
# (acceso directo desde el resumen) y se retorna 0 al aceptar o 1 con Atrás.
run_wizard() {
    local i="${1:-0}" only="${2:-}" n=${#WIZARD_STEPS[@]} rc
    while (( i >= 0 && i < n )); do
        CURRENT_STEP="${WIZARD_STEPS[$i]}"
        if "$CURRENT_STEP"; then
            rc=0
        else
            rc=$?
        fi
        if [[ $rc -eq 0 ]]; then
            STEP_OK[$CURRENT_STEP]=1
            [[ -n "$only" ]] && return 0
            i=$((i + 1))
        else
            [[ -n "$only" ]] && return 1
            if (( i == 0 )); then confirm_exit; else i=$((i - 1)); fi
        fi
    done
    return 0
}

ask_questions() {
    header "Configuración de la instalación"
    run_wizard
}

# ── Pregunta: disco ───────────────────────────────────────────────────────────
step_disk() {
    local line disk def=()
    echo -e "\n   ${BOLD}Discos disponibles:${NC}"
    local disk_list=()
    while IFS= read -r line; do
        disk_list+=("$line")
    done < <(lsblk -dpno NAME,SIZE,MODEL | grep -Ev "loop|sr|zram")

    local disk_opts=()
    for entry in "${disk_list[@]}"; do
        local dname
        local ddesc

        dname=$(awk '{print $1}' <<< "$entry")
        ddesc=$(awk '{print $2 " " substr($0, index($0,$3))}' <<< "$entry")
        disk_opts+=("$dname" "$ddesc")
    done

    if answered; then def=(--default-item "$TARGET_DISK"); fi
    wt --title "Selección de Disco" "${def[@]}" --menu "Elige el disco de instalación (¡SE BORRARÁ TODO!):" 15 70 6 "${disk_opts[@]}" || return 1
    disk="$WT_OUT"
    ok "Disco seleccionado: $disk"
    [[ -b "$disk" ]] || die "Disco no encontrado: $disk"

    # Aquí no se borra nada: solo se avisa. La limpieza (wipefs -af) ocurre en partition_disk,
    # después de la última confirmación del resumen.
    if wipefs -n "$disk" 2>/dev/null | grep -q .; then
        warn "El disco $disk contiene datos previos; se borrarán al confirmar la instalación."
    else
        ok "Disco $disk está limpio"
    fi
    TARGET_DISK="$disk"
    return 0
}

# ── Preguntas: sistema ────────────────────────────────────────────────────────
# Cada pregunta trabaja con una copia local y solo guarda la respuesta si es válida:
# con Atrás la información anterior no cambia.
step_hostname() {
    local v="$SYS_HOSTNAME"
    while true; do
        ask "Nombre del equipo (hostname)" v "$v" || return 1
        [[ -n "$v" ]] && break
        whiptail --title "Error" --msgbox "El hostname no puede estar vacío." 8 60
    done
    SYS_HOSTNAME="$v"
    return 0
}

step_username() {
    local v="$USERNAME"
    while true; do
        ask "Nombre de usuario" v "$v" || return 1
        [[ "$v" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
        whiptail --title "Error" --msgbox "Usuario inválido: solo letras minúsculas, números, _ y -" 8 60
    done
    USERNAME="$v"
    return 0
}

step_fullname() {
    local v="$FULLNAME"
    while true; do
        ask "Nombre completo del usuario" v "$v" || return 1
        if [[ ! "$v" =~ [^[:space:]] ]]; then
            whiptail --title "Error" --msgbox "El nombre completo no puede estar vacío." 8 60
        elif [[ "$v" == *:* || "$v" =~ [[:cntrl:]] ]]; then
            whiptail --title "Error" --msgbox "Nombre completo inválido: no puede contener ':' ni caracteres de control." 8 70
        else
            break
        fi
    done
    FULLNAME="$v"
    return 0
}

step_userpass() {
    local v="$USERPASS"
    while true; do
        askpass "Contraseña para $USERNAME" v || return 1
        [[ -n "$v" ]] && break
        whiptail --title "Error" --msgbox "La contraseña no puede estar vacía." 8 60
    done
    USERPASS="$v"
    return 0
}

# ── Pregunta: LUKS ────────────────────────────────────────────────────────────
# $1 = nombre de la variable donde queda la passphrase. Retorna 1 con Atrás.
ask_luks_pass() {
    local name="$1" val
    while true; do
        askpass "Passphrase LUKS (se pedirá en cada arranque)" "$name" || return 1
        val="${!name}"
        [[ ${#val} -ge 8 ]] && return 0
        whiptail --title "Error" --msgbox "Passphrase demasiado corta (mínimo 8 caracteres)." 8 60
        printf -v "$name" '%s' ""
    done
}

step_luks() {
    local use="$USE_LUKS" pass="$LUKS_PASS" seen=""
    while true; do
        ask_yesno "¿Cifrado completo del disco con LUKS2?" use "$seen" || return 1
        seen=1
        if [[ "$use" == "false" ]]; then
            pass=""
            break
        fi
        if ask_luks_pass pass; then
            ok "Cifrado LUKS2 habilitado"
            break
        fi
    done
    USE_LUKS="$use"
    LUKS_PASS="$pass"
    return 0
}

# ── Pregunta: hibernación y swap ──────────────────────────────────────────────
# La swap sugerida se recalcula solo cuando cambia la respuesta de hibernación;
# si no cambia, se conserva el tamaño que el usuario ya eligió.
step_swap() {
    local hib="$USE_HIBERNATE" swap="$SWAP_SIZE" prev="" seen=""
    if answered; then prev="$USE_HIBERNATE"; fi
    echo -e "\n   ${BOLD}RAM detectada: ${RAM_GB} GB${NC}"
    echo -e "   ${DIM}Referencia swap:${NC}"
    echo -e "   ${DIM}  Sin hibernación: $(suggest_swap false) GB sugeridos${NC}"
    echo -e "   ${DIM}  Con hibernación: $(suggest_swap true) GB sugeridos${NC}"

    while true; do
        ask_yesno "¿Soporte de hibernación (suspend-to-disk)?" hib "$seen" || return 1
        seen=1
        if [[ "$hib" != "$prev" ]]; then
            swap=$(suggest_swap "$hib")
            prev="$hib"
        fi
        if [[ "$hib" == "true" ]]; then
            info "Swap calculada para hibernación: ${swap} GB"
        else
            info "Swap sugerida: ${swap} GB"
        fi
        ask_number "Tamaño del swap en GB" swap "$swap" && break
    done
    USE_HIBERNATE="$hib"
    SWAP_SIZE="$swap"
    return 0
}

# ── Pregunta: Docker ──────────────────────────────────────────────────────────
step_docker() {
    ask_yesno "¿Subvolumen @docker para /var/lib/docker? (recomendado si usarás Docker)" USE_DOCKER || return 1
    if $USE_DOCKER; then ok "Subvolumen @docker incluido"; fi
    return 0
}

# ── Pregunta: shell interactivo ───────────────────────────────────────────────
step_shell() {
    local def=()
    if answered; then def=(--default-item "$SHELL_CHOICE"); fi
    wt --title "Shell Interactivo" "${def[@]}" --menu "Selecciona la configuración del shell:" 15 70 3 \
        "bash" "Bash mejorado (ble.sh + Oh My Bash)" \
        "zsh" "ZSH con plugins (syntax-highlighting, autosuggestions)" \
        "none" "Ninguno (Bash por defecto)" || return 1
    
    SHELL_CHOICE="$WT_OUT"
    ok "Shell seleccionado: $SHELL_CHOICE"
    return 0
}

# ─── 5. Resumen y confirmación ────────────────────────────────────────────────
# Texto del cuadro de diálogo del resumen: un renglón de introducción, seis renglones con las
# respuestas y una ayuda. Cabe en una terminal de 24 filas.
summary_text() {
    local shell_desc="sin cambios (bash)" subvols="@  @home  @log  @snapshots  @pkg  @swap"
    case "$SHELL_CHOICE" in
        bash) shell_desc="Bash mejorado" ;;
        zsh)  shell_desc="ZSH con plugins" ;;
        none) shell_desc="ninguno (bash sin modificar)" ;;
    esac
    if $USE_DOCKER; then subvols+="  @docker"; fi
    echo "Revisa tus respuestas. No se escribe nada en el disco hasta que confirmes."
    echo
    echo "Disco:      $TARGET_DISK  (se borra TODO su contenido)"
    echo "Equipo:     $SYS_HOSTNAME  ·  usuario $USERNAME ($FULLNAME)"
    echo "Región:     $TIMEZONE  ·  $LOCALE  ·  teclado ${XKB_LAYOUT}${XKB_VARIANT:+ / $XKB_VARIANT}"
    echo "Seguridad:  LUKS2 $( $USE_LUKS && echo 'SI' || echo 'NO' )  ·  hibernación $( $USE_HIBERNATE && echo 'SI' || echo 'NO' )  ·  swap ${SWAP_SIZE} GB"
    echo "Sistema:    GPU $GPU_TYPE  ·  Docker $( $USE_DOCKER && echo 'SI' || echo 'NO' )  ·  shell $shell_desc"
    echo "BTRFS:      $subvols"
    echo
    echo "Elige con ↑ ↓ y Enter. Atrás vuelve a la última pregunta; Esc pide salir."
}

# Lista de preguntas que se pueden cambiar. Al cambiar una se vuelve al resumen, que ya muestra
# el valor nuevo. «Volver al resumen» y Atrás regresan sin cambiar nada; «Salir» pide confirmar.
modify_menu() {
    local items choice i
    items=(
        "step_disk"     "Disco: $TARGET_DISK"
        "step_hostname" "Hostname: $SYS_HOSTNAME"
        "step_username" "Usuario: $USERNAME"
        "step_fullname" "Nombre completo: $FULLNAME"
        "step_userpass" "Contraseña: ********"
        "ask_timezone"  "Zona horaria: $TIMEZONE"
        "ask_locale"    "Idioma: $LOCALE"
        "ask_keyboard"  "Teclado: ${XKB_LAYOUT}${XKB_VARIANT:+ / $XKB_VARIANT} (vconsole: $KEYMAP)"
        "step_luks"     "Cifrado LUKS2: $( $USE_LUKS && echo 'SI' || echo 'NO' )"
        "step_swap"     "Hibernación: $( $USE_HIBERNATE && echo 'SI' || echo 'NO' ) — Swap: ${SWAP_SIZE} GB"
        "step_docker"   "Subvolumen @docker: $( $USE_DOCKER && echo 'SI' || echo 'NO' )"
        "step_shell"    "Shell: $SHELL_CHOICE"
        "volver"        "Volver al resumen"
        "salir"         "Salir del instalador"
    )
    while true; do
        wt --title "Modificar una opción" --notags --menu "Elige la opción que quieres cambiar:" 22 78 14 "${items[@]}" || return 0
        choice="$WT_OUT"
        case "$choice" in
            volver) return 0 ;;
            salir)  confirm_exit ;;
            *)
                for i in "${!WIZARD_STEPS[@]}"; do
                    [[ "${WIZARD_STEPS[$i]}" == "$choice" ]] && run_wizard "$i" solo
                done
                return 0
                ;;
        esac
    done
}

# Muestra el resumen dentro del cuadro de diálogo con dos opciones: confirmar la instalación o
# modificar alguna respuesta. «Confirmar la instalación» pide una última confirmación, con «No»
# por defecto; «No» vuelve a este menú. Atrás vuelve a la última pregunta; Esc pide confirmar la salida.
show_summary() {
    local choice
    while true; do
        if ! wt --title "Resumen de instalación" --notags --default-item "instalar" \
                --menu "$(summary_text)" 21 78 2 \
                "instalar"  "Confirmar la instalación" \
                "modificar" "¿Deseas modificar alguna opción?"; then
            run_wizard $(( ${#WIZARD_STEPS[@]} - 1 ))
            continue
        fi
        choice="$WT_OUT"
        case "$choice" in
            instalar)
                if confirm "Se borrarán TODOS los datos de $TARGET_DISK de forma irreversible. ¿Estás seguro de continuar?" --defaultno; then
                    return 0
                fi
                ;;
            modificar) modify_menu ;;
        esac
    done
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
    if ! command -v cachyos-rate-mirrors &>/dev/null; then
        step "Instalando cachyos-rate-mirrors..."
        sudo pacman -S --noconfirm cachyos-rate-mirrors || warn "No se pudo instalar cachyos-rate-mirrors"
    fi
    sudo cachyos-rate-mirrors \
        || warn "cachyos-rate-mirrors falló — usando lista de mirrors actual"
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
        man-db less unzip rsync paru
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
    if ! command -v cachyos-rate-mirrors &>/dev/null; then
        step "Instalando cachyos-rate-mirrors..."
        sudo pacman -S --noconfirm cachyos-rate-mirrors || warn "No se pudo instalar cachyos-rate-mirrors"
    fi
    sudo cachyos-rate-mirrors \
        || warn "cachyos-rate-mirrors falló — usando lista de mirrors actual"
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
    genfstab -U /mnt > /mnt/etc/fstab \
        || die "genfstab falló"
    ok "fstab generado"
}

# ─── 14. Repos CachyOS en el sistema instalado ────────────────────────────────

configure_cachyos_repos() {
    step "Configurando repos CachyOS en el sistema instalado..."

    # El live USB ya tiene el pacman.conf correcto con todos los repos CachyOS
    cp /etc/pacman.conf /mnt/etc/pacman.conf \
        || die "No se pudo copiar /etc/pacman.conf al sistema instalado"

    # Copiar todas las mirrorlists de CachyOS disponibles en el Live USB.
    # Incluye automáticamente variantes actuales como v3, v4 y znver4.
    local mirrorlist
    while IFS= read -r -d '' mirrorlist; do
        cp "$mirrorlist" /mnt/etc/pacman.d/
    done < <(
        find /etc/pacman.d -maxdepth 1 -type f             -name 'cachyos*-mirrorlist' -print0
    )

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

echo "Instalando bootloader GRUB..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=CachyOS --recheck || die "ERROR FATAL: grub-install estandar fallo."
echo "Instalando copia de respaldo GRUB en modo removable (fallback UEFI)..."
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable || die "ERROR FATAL: grub-install removable fallo por completo."

grub-mkconfig -o /boot/grub/grub.cfg
CHROOT

    # ── Usuario — arch-chroot separado para usar variables del shell externo ───
    arch-chroot /mnt useradd -m -G wheel,audio,video,storage,optical \
        -s /bin/bash -c "${FULLNAME}" "${USERNAME}" \
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
                # shellcheck disable=SC2016
                printf '%s\n' 'if [[ -n "$SSH_CONNECTION" ]] && ! infocmp "$TERM" &>/dev/null 2>&1; then'
                printf '%s\n' '  export TERM=xterm-256color'
                printf '%s\n\n' 'fi'
                printf '%s\n\n' '[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --noattach 2>/dev/null'
                printf '%s\n' "$content"
                # shellcheck disable=SC2016
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

# ─── 16b. Repositorio en la carpeta del usuario ───────────────────────────────
# Descarga el repositorio en /home/<usuario>/cachyos-install y deja un aviso para el primer
# inicio de sesión. Es un extra: si algo falla avisa y la instalación continúa sin el aviso.
install_repo_home() {
    step "Descargando el repositorio en /home/$USERNAME/cachyos-install..."
    if ! arch-chroot /mnt pacman -S --needed --noconfirm git; then
        warn "No se pudo instalar git: el repositorio no se descargó."
        return 0
    fi
    if ! arch-chroot /mnt /bin/su -l "$USERNAME" -s /bin/bash -c "git clone '$REPO_URL' \"\$HOME/cachyos-install\""; then
        warn "No se pudo descargar el repositorio desde $REPO_URL."
        return 0
    fi
    REPO_CLONED=true
    ok "Repositorio descargado en /home/$USERNAME/cachyos-install"

    # Aviso del primer inicio de sesión: un marcador y un bloque al principio del rc del shell.
    # El bloque muestra el mensaje y borra el marcador, por eso sale una sola vez.
    local rc="/mnt/home/$USERNAME/.bashrc"
    if [[ "$SHELL_CHOICE" == "zsh" ]]; then rc="/mnt/home/$USERNAME/.zshrc"; fi
    # shellcheck disable=SC2016
    if ! arch-chroot /mnt /bin/su -l "$USERNAME" -s /bin/bash -c 'mkdir -p "$HOME/.config/cachyos-install" && : > "$HOME/.config/cachyos-install/primer-inicio"'; then
        warn "No se pudo crear el marcador del aviso de primer inicio de sesión."
        return 0
    fi
    if [[ ! -f "$rc" ]]; then touch "$rc"; fi
    cat > "${rc}.new" << 'AVISO'
# cachyos-install: aviso del primer inicio de sesión (borra su marcador al mostrarse)
if [[ $- == *i* && -f "$HOME/.config/cachyos-install/primer-inicio" ]]; then
    printf '\n  El repositorio cachyos-install está en ~/cachyos-install.\n  Para continuar con la instalación, ejecuta:\n\n      cd ~/cachyos-install && ./install.sh\n\n'
    rm -f "$HOME/.config/cachyos-install/primer-inicio"
fi

AVISO
    cat "$rc" >> "${rc}.new"
    mv "${rc}.new" "$rc"
    arch-chroot /mnt chown "$USERNAME:$USERNAME" "/home/$USERNAME/${rc##*/}"
    ok "Aviso del primer inicio de sesión configurado en ~/${rc##*/}"
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
echo "✓ Rollback completado."
echo ""
echo "IMPORTANTE:"
echo "  - Se creó un nuevo subvolumen Btrfs @."
echo "  - No se creó un nuevo ID de snapshot en Snapper."
echo "  - El sistema anterior se conservó como @_old_$TIMESTAMP."
echo "  - No elimines ese backup hasta validar el sistema restaurado."
echo ""
echo "Cuando sea seguro reiniciar: sudo reboot"
ROLLBACK_SCRIPT

    chmod 755 /mnt/usr/local/bin/btrfs-rollback
    ok "Helper btrfs-rollback instalado en /usr/local/bin"
}

# ─── 16. Snapshot inicial ─────────────────────────────────────────────────────
take_snapshot() {
    step "Creando snapshot inicial..."
    arch-chroot /mnt snapper --no-dbus -c root create \
        --description "sistema-base-instalado" \
        --userdata "important=yes" \
        || die "Error creando snapshot inicial"
    ok "Snapshot inicial creado"
}

# ─── 18. Desmontaje ───────────────────────────────────────────────────────────
unmount_all() {
    step "Desmontando..."
    swapoff /mnt/swap/swapfile 2>/dev/null || true
    umount -R /mnt
    if $USE_LUKS; then cryptsetup close cryptroot 2>/dev/null || true; fi
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
    echo -e "   ${BOLD}Nombre completo:${NC} $FULLNAME"
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
    if $REPO_CLONED; then
        info "   El repositorio ya esta en /home/$USERNAME/cachyos-install y tu primer inicio de sesion"
        info "   mostrara un aviso con el comando. Para instalar Hyprland, ejecuta como usuario normal:"
        echo -e "\n      ${BOLD}cd ~/cachyos-install && ./install.sh${NC}\n"
    else
        warn "   El repositorio no se pudo descargar. Para instalar Hyprland, ejecuta como usuario normal:"
        echo -e "\n      ${BOLD}git clone $REPO_URL ~/cachyos-install${NC}"
        echo -e "      ${BOLD}cd ~/cachyos-install && ./install.sh${NC}\n"
    fi
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
install_repo_home
install_rollback_helper
take_snapshot
unmount_all
final_summary
exit 0
