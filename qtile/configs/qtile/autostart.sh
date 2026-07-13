#!/bin/bash
# Autostart para Qtile - Estilo Omarchy

# 0. Configurar Monitores (HDMI-2 Izquierda, HDMI-1 Derecha) — solo si existen
if xrandr --query | grep -q "^HDMI-2 connected"; then
    xrandr --output HDMI-2 --mode 1366x768 --pos 0x0 --output HDMI-1 --mode 1920x1080 --pos 1366x0
fi

# 0.1 Configurar teclado (preferencia de usuario, fallback a config del sistema)
kb_pref="$HOME/.config/qtile/keyboard_layout"
if [[ -f "$kb_pref" ]]; then
    source "$kb_pref"
    if [[ -n "$kb_variant" ]]; then
        setxkbmap "$kb_layout" -variant "$kb_variant" &
    else
        setxkbmap "$kb_layout" &
    fi
else
    kb_layout=$(grep -i "XkbLayout" /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null | awk -F'"' '{print $4}' | xargs)
    kb_variant=$(grep -i "XkbVariant" /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null | awk -F'"' '{print $4}' | xargs)
    kb_layout="${kb_layout:-us}"
    if [[ -z "$kb_variant" ]]; then
        setxkbmap "$kb_layout" &
    else
        setxkbmap "$kb_layout" -variant "$kb_variant" &
    fi
fi

# 0.2 Restaurar preferencia de audio
audio_pref="$HOME/.config/qtile/audio_preference"
if [[ -f "$audio_pref" ]]; then
    source "$audio_pref"
    
    # Obtener el nombre de la tarjeta de sonido actual de forma dinámica
    card_name=$(pactl list cards short | awk '{print $2}' | grep "alsa_card" | head -n 1)
    
    if [[ -n "$card_name" ]]; then
        # 1. Aplicar perfil de tarjeta si está guardado
        if [[ -n "$audio_profile" ]]; then
            pactl set-card-profile "$card_name" "$audio_profile"
        fi
        
        # 2. Restaurar la salida por defecto (sink)
        if [[ -n "$audio_sink" ]]; then
            # Si el sink guardado pertenece a ALSA, reconstruimos el nombre del sink
            # dinámicamente usando el card_name actual por si varía el identificador PCI
            if [[ "$audio_sink" == alsa_output.* ]]; then
                actual_prefix="${card_name/alsa_card/alsa_output}"
                suffix="${audio_sink##*.}"
                pactl set-default-sink "${actual_prefix}.${suffix}"
            else
                pactl set-default-sink "$audio_sink"
            fi
        fi

        # 3. Asegurar que los canales ALSA físicos estén desmutados según el perfil
        if [[ "$audio_id" == "headphones" ]]; then
            amixer -c 0 sset Master unmute &>/dev/null || true
            amixer -c 0 sset Headphone unmute &>/dev/null || true
            amixer -c sofhdadsp sset Master unmute &>/dev/null || true
            amixer -c sofhdadsp sset Headphone unmute &>/dev/null || true
        elif [[ "$audio_id" == "speaker" ]]; then
            amixer -c 0 sset Master unmute &>/dev/null || true
            amixer -c 0 sset Speaker unmute &>/dev/null || true
            amixer -c sofhdadsp sset Master unmute &>/dev/null || true
            amixer -c sofhdadsp sset Speaker unmute &>/dev/null || true
        fi
    fi
fi

# 1. Iniciar Picom (Comentado si da error sin config)
if [ -f ~/.config/picom/picom.conf ]; then
    picom --config ~/.config/picom/picom.conf -b &
else
    picom -b &
fi

# 2. Establecer el fondo de pantalla de Omarchy
if [ -f ~/.config/omarchy/current/background ]; then
    feh --bg-fill "$(cat ~/.config/omarchy/current/background)" &
fi

# 3. Autenticación y automontaje
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
udiskie &

# 4. Applets de red y bluetooth
nm-applet &
blueman-applet &

# 5. Notificaciones y cuidado ocular
dunst &
# redshift &
snixembed &
safeeyes &

# 6. Eww Sysmon (widget de escritorio)
# eww daemon &
# eww open sysmon &

# 7. Gestor de Portapapeles (Greenclip)
greenclip daemon &

# 8. Monitor setup listener daemon
~/.local/bin/qtile-monitor-listener &

# 9. Cargar configuraciones de pantalla, energía y autolock
if [[ -f ~/.cache/qtile-idle-command.sh ]]; then
    bash ~/.cache/qtile-idle-command.sh &
else
    # Configuración por defecto: bloquear a los 10 min, pantalla off a los 15 min, suspender a los 30 min
    xset +dpms
    xset dpms 900 900 900
    nohup xautolock -detectdelay 1 -time 10 -locker "qtile-lock" -killtime 20 -killer "systemctl suspend" >/dev/null 2>&1 &
fi

