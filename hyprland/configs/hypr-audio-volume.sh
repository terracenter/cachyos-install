#!/usr/bin/env bash
# hypr-audio-volume - Control de volumen de la aplicacion enfocada en Hyprland.
#
# Uso:
#   hypr-audio-volume raise [paso]
#   hypr-audio-volume lower [paso]
#   hypr-audio-volume mute-toggle
#
# Ejemplos:
#   hypr-audio-volume raise 5%
#   hypr-audio-volume lower 5%
#   hypr-audio-volume mute-toggle

set -Eeuo pipefail

ACTION="${1:-raise}"
STEP="${2:-5%}"

log_error() {
    printf '[hypr-audio-volume] ERROR: %s\n' "$*" >&2
}

notify() {
    local title="$1"
    local message="$2"

    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "$title" "$message" --urgency=low --expire-time=1600
}

for dep in jq pactl hyprctl; do
    command -v "$dep" >/dev/null 2>&1 || {
        log_error "'$dep' no encontrado"
        exit 1
    }
done

case "$ACTION" in
    raise|lower|mute-toggle) ;;
    *)
        log_error "accion no valida: $ACTION"
        log_error "usa: raise, lower o mute-toggle"
        exit 2
        ;;
esac

if [[ "$ACTION" != "mute-toggle" && ! "$STEP" =~ ^[0-9]+([.][0-9]+)?%$ ]]; then
    log_error "paso no valido: $STEP"
    log_error "ejemplo valido: 5%"
    exit 2
fi

ACTIVE_PID="${ACTIVE_PID_OVERRIDE:-$(hyprctl activewindow -j 2>/dev/null | jq -r '.pid // empty')}"
ACTIVE_CLASS="$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // "Aplicacion"')"

# Devuelve 0 cuando CHILD_PID es igual o descendiente de ROOT_PID.
# Se recorre /proc para cubrir aplicaciones multiproceso como Chrome y Discord.
is_descendant_of() {
    local child_pid="$1"
    local root_pid="$2"
    local current_pid="$child_pid"
    local parent_pid
    local guard=0

    [[ "$child_pid" =~ ^[0-9]+$ && "$root_pid" =~ ^[0-9]+$ ]] || return 1

    while (( current_pid > 1 && guard < 128 )); do
        [[ "$current_pid" == "$root_pid" ]] && return 0
        [[ -r "/proc/$current_pid/status" ]] || return 1

        parent_pid=$(awk '/^PPid:/ { print $2; exit }' "/proc/$current_pid/status")
        [[ "$parent_pid" =~ ^[0-9]+$ ]] || return 1
        [[ "$parent_pid" == "$current_pid" ]] && return 1

        current_pid="$parent_pid"
        ((guard += 1))
    done

    return 1
}

adjust_system_volume() {
    if command -v swayosd-client >/dev/null 2>&1; then
        case "$ACTION" in
            raise)       swayosd-client --output-volume raise >/dev/null 2>&1 || true ;;
            lower)       swayosd-client --output-volume lower >/dev/null 2>&1 || true ;;
            mute-toggle) swayosd-client --output-volume mute-toggle >/dev/null 2>&1 || true ;;
        esac
    else
        case "$ACTION" in
            raise)       pactl set-sink-volume @DEFAULT_SINK@ "+$STEP" ;;
            lower)       pactl set-sink-volume @DEFAULT_SINK@ "-$STEP" ;;
            mute-toggle) pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
        esac
    fi

    notify "Volumen del sistema" "La ventana enfocada no tiene un flujo de audio activo."
}

if [[ -z "$ACTIVE_PID" || ! "$ACTIVE_PID" =~ ^[0-9]+$ ]]; then
    adjust_system_volume
    exit 0
fi

SINK_INPUTS_JSON=$(pactl -f json list sink-inputs 2>/dev/null || printf '[]')

mapfile -t STREAM_ROWS < <(
    jq -r '.[] |
        [
            (.index | tostring),
            (.properties["application.process.id"] // ""),
            (.properties["application.name"] //
             .properties["application.process.binary"] //
             .properties["media.name"] // "Audio")
        ] | @tsv' <<< "$SINK_INPUTS_JSON"
)

STREAM_IDS=()
STREAM_NAMES=()

for row in "${STREAM_ROWS[@]}"; do
    IFS=$'\t' read -r stream_id stream_pid stream_name <<< "$row"

    [[ "$stream_id" =~ ^[0-9]+$ ]] || continue
    [[ "$stream_pid" =~ ^[0-9]+$ ]] || continue

    if is_descendant_of "$stream_pid" "$ACTIVE_PID"; then
        STREAM_IDS+=("$stream_id")
        STREAM_NAMES+=("$stream_name")
    fi
done

if (( ${#STREAM_IDS[@]} == 0 )); then
    adjust_system_volume
    exit 0
fi

for stream_id in "${STREAM_IDS[@]}"; do
    case "$ACTION" in
        raise)
            pactl set-sink-input-volume "$stream_id" "+$STEP"
            ;;
        lower)
            pactl set-sink-input-volume "$stream_id" "-$STEP"
            ;;
        mute-toggle)
            pactl set-sink-input-mute "$stream_id" toggle
            ;;
    esac
done

# Leer el estado actualizado del primer flujo para mostrar informacion util.
FIRST_STREAM_ID="${STREAM_IDS[0]}"
UPDATED_JSON=$(pactl -f json list sink-inputs 2>/dev/null || printf '[]')
VOLUME_PERCENT=$(
    jq -r --argjson id "$FIRST_STREAM_ID" '
        .[] | select(.index == $id) |
        [.volume[]?.value_percent
         | strings
         | sub("%$"; "")
         | tonumber] |
        if length > 0 then ((add / length) | round | tostring) + "%" else empty end
    ' <<< "$UPDATED_JSON" | head -n 1
)
MUTED=$(
    jq -r --argjson id "$FIRST_STREAM_ID" \
        '.[] | select(.index == $id) | (.mute // false)' \
        <<< "$UPDATED_JSON" | head -n 1
)

STREAM_COUNT="${#STREAM_IDS[@]}"
DISPLAY_NAME="${ACTIVE_CLASS:-${STREAM_NAMES[0]}}"

if [[ "$MUTED" == "true" ]]; then
    STATUS="silenciado"
elif [[ -n "$VOLUME_PERCENT" ]]; then
    STATUS="$VOLUME_PERCENT"
else
    STATUS="$ACTION"
fi

if (( STREAM_COUNT > 1 )); then
    notify "Audio: $DISPLAY_NAME" "$STATUS en $STREAM_COUNT flujos"
else
    notify "Audio: $DISPLAY_NAME" "$STATUS"
fi
