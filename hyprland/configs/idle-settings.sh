#!/usr/bin/env bash
# Menu Rofi "Pantalla y energia" para Hyprland.
# Escribe ~/.config/hypr/hypridle.conf y reinicia hypridle.
# Sin argumentos abre el menu; con --render solo escribe la configuracion
# (lo usa el instalador, que corre sin sesion grafica).
set -Eeuo pipefail

hypr_dir="${IDLE_HYPR_DIR:-$HOME/.config/hypr}"
state_dir="$hypr_dir/idle"
conf="$hypr_dir/hypridle.conf"
power_state="${IDLE_POWER_STATE:-/sys/power/state}"
mark='# Generado por idle-settings. Para cambiarlo usa el menu Pantalla y energia.'

lock_min=10
action=Ninguna
action_min=30

read_value() {
    local file=$1 default=$2 value
    if [[ -r $file ]]; then value=$(<"$file"); else value=$default; fi
    printf '%s' "$value"
}

load_state() {
    lock_min=$(read_value "$state_dir/lock_min" 10)
    [[ $lock_min =~ ^[0-9]+$ ]] || lock_min=10
    action=$(read_value "$state_dir/action" Ninguna)
    [[ $action == Suspender || $action == Hibernar ]] || action=Ninguna
    action_min=$(read_value "$state_dir/action_min" 30)
    [[ $action_min =~ ^[0-9]+$ ]] || action_min=30
}

save_state() {
    mkdir -p "$state_dir"
    printf '%s\n' "$lock_min" > "$state_dir/lock_min"
    printf '%s\n' "$action" > "$state_dir/action"
    printf '%s\n' "$action_min" > "$state_dir/action_min"
}

conf_is_ours() {
    [[ ! -e $conf ]] || grep -qxF "$mark" "$conf"
}

render_conf() {
    local lock_sec=$(( lock_min * 60 )) action_sec=0 dpms_sec=0 action_cmd=''
    case "$action" in
        Suspender) action_cmd='systemctl suspend' ;;
        Hibernar) action_cmd='systemctl hibernate' ;;
    esac
    if [[ -n $action_cmd && $action_min -gt 0 ]]; then
        action_sec=$(( action_min * 60 ))
    fi
    if [[ $lock_sec -gt 0 ]]; then
        dpms_sec=$(( lock_sec + 300 ))
        if [[ $action_sec -gt 0 && $dpms_sec -ge $action_sec ]]; then
            dpms_sec=0
        fi
    fi

    mkdir -p "$hypr_dir"
    {
        printf '%s\n\n' "$mark"
        printf 'general {\n'
        printf '    lock_cmd = pidof hyprlock || hyprlock\n'
        if [[ $lock_sec -gt 0 ]]; then
            printf '    before_sleep_cmd = loginctl lock-session\n'
        fi
        cat <<'EOF_GENERAL'
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({action = "on"})'
}
EOF_GENERAL
        if [[ $lock_sec -gt 0 ]]; then
            printf '\nlistener {\n    timeout = %s\n    on-timeout = loginctl lock-session\n}\n' "$lock_sec"
        fi
        if [[ $dpms_sec -gt 0 ]]; then
            printf '\nlistener {\n    timeout = %s\n' "$dpms_sec"
            cat <<'EOF_DPMS'
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({action = "off"})'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({action = "on"})'
}
EOF_DPMS
        fi
        if [[ $action_sec -gt 0 ]]; then
            printf '\nlistener {\n    timeout = %s\n    on-timeout = %s\n}\n' "$action_sec" "$action_cmd"
        fi
    } > "$conf.new"
    mv -f "$conf.new" "$conf"
}

hibernate_supported() {
    grep -qw disk "$power_state" 2>/dev/null || return 1
    [[ -n "$(swapon --noheadings --show=NAME 2>/dev/null)" ]]
}

to_minutes() {
    case "$1" in
        '5 minutos') echo 5 ;;
        '10 minutos') echo 10 ;;
        '15 minutos') echo 15 ;;
        '20 minutos') echo 20 ;;
        '30 minutos') echo 30 ;;
        '60 minutos') echo 60 ;;
        '120 minutos') echo 120 ;;
        Nunca) echo 0 ;;
        *) echo -1 ;;
    esac
}

pick_time() {
    printf '%s\n' '5 minutos' '10 minutos' '15 minutos' '20 minutos' '30 minutos' '60 minutos' '120 minutos' 'Nunca' \
        | rofi -dmenu -i -p "$1" -theme-str 'window {width: 300px;} listview {lines: 8;}'
}

pick_action() {
    if hibernate_supported; then
        printf '%s\n' 'Suspender' 'Hibernar' 'Ninguna'
    else
        printf '%s\n' 'Suspender' 'Ninguna'
    fi | rofi -dmenu -i -p "$1" -theme-str 'window {width: 300px;} listview {lines: 3;}'
}

restart_hypridle() {
    pkill -x hypridle 2>/dev/null || true
    nohup uwsm app -- hypridle >/dev/null 2>&1 &
}

if [[ ${1:-} == --render ]]; then
    if ! conf_is_ours; then
        printf 'hypridle.conf propio conservado: %s\n' "$conf"
        exit 0
    fi
    load_state
    save_state
    render_conf
    printf 'hypridle.conf escrito: %s\n' "$conf"
    exit 0
fi

if ! conf_is_ours; then
    notify-send -u critical 'Pantalla y energia' \
        "Existe un hypridle.conf propio en $conf. Renombralo para usar este menu."
    exit 1
fi

load_state

lock_choice=$(pick_time "Bloquear pantalla [actual: ${lock_min} min]") || exit 0
new_lock=$(to_minutes "$lock_choice")
[[ $new_lock -ge 0 ]] || exit 1

action_choice=$(pick_action "Accion de energia [actual: ${action}]") || exit 0
new_action=Ninguna
new_action_min=0
case "$action_choice" in
    Suspender|Hibernar) new_action=$action_choice ;;
    Ninguna) ;;
    *) exit 1 ;;
esac

if [[ $new_action != Ninguna ]]; then
    time_choice=$(pick_time "${new_action} [actual: ${action_min} min]") || exit 0
    new_action_min=$(to_minutes "$time_choice")
    [[ $new_action_min -ge 0 ]] || exit 1
    if [[ $new_lock -gt 0 && $new_action_min -gt 0 && $new_action_min -le $new_lock ]]; then
        notify-send -u critical 'Pantalla y energia' \
            "El tiempo de ${new_action,,} debe ser mayor que el de bloqueo."
        exit 1
    fi
    if [[ $new_action_min -eq 0 ]]; then
        new_action=Ninguna
    fi
fi

lock_min=$new_lock
action=$new_action
action_min=$new_action_min
save_state
render_conf
restart_hypridle

if [[ $lock_min -gt 0 ]]; then
    summary="Bloqueo a los ${lock_min} min."
else
    summary='Bloqueo automatico desactivado.'
fi
if [[ $action != Ninguna ]]; then
    summary="$summary ${action} a los ${action_min} min."
fi
notify-send 'Pantalla y energia' "$summary"
