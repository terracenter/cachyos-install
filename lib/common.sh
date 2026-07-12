#!/bin/bash
# Funciones comunes compartidas entre instaladores (Hyprland, Qtile)

detect_keyboard_layout() {
    # Detectar layout de teclado desde configuración del sistema (vconsole/X11)
    # Exporta SYS_KB_LAYOUT y SYS_KB_VARIANT como variables globales

    SYS_KB_LAYOUT=$(localectl status 2>/dev/null | grep "X11 Layout" | awk -F': ' '{print $2}' | xargs)
    SYS_KB_VARIANT=$(localectl status 2>/dev/null | grep "X11 Variant" | awk -F': ' '{print $2}' | xargs)

    # Fallback a /etc/X11/xorg.conf.d/00-keyboard.conf si localectl no retorna nada
    if [[ -z "$SYS_KB_LAYOUT" ]]; then
        SYS_KB_LAYOUT=$(grep -i "XkbLayout" /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null | awk -F'"' '{print $4}' | xargs)
        SYS_KB_VARIANT=$(grep -i "XkbVariant" /etc/X11/xorg.conf.d/00-keyboard.conf 2>/dev/null | awk -F'"' '{print $4}' | xargs)
    fi

    # Fallback final: US si no se puede detectar nada
    SYS_KB_LAYOUT="${SYS_KB_LAYOUT:-us}"
    SYS_KB_VARIANT="${SYS_KB_VARIANT:-}"
}
