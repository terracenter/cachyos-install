#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HYPRLAND_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
# shellcheck source=../basico/helpers.sh
source "$HYPRLAND_DIR/install/basico/helpers.sh"

show_script_version "Apariencia y controles de sesion" "${BASH_SOURCE[0]}"
[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

step "Instalando temas, bloqueo y controles de sesion"
source_dir="$HYPRLAND_DIR/themes"
themes_dir="$HOME/.config/omarchy/themes"
current_dir="$HOME/.config/omarchy/current"
templates_dir="$HOME/.local/share/omarchy-local/themed"
backgrounds_dir="$HOME/.local/share/backgrounds"
bin_dir="$HOME/.local/bin"
lock_dir="$HOME/.config/hypr/lockscreen"
private_signature="$HOME/.local/share/hyprlock/company-signature.png"

mkdir -p "$themes_dir" "$current_dir" "$templates_dir" "$backgrounds_dir" \
    "$bin_dir" "$lock_dir"

find "$source_dir" -mindepth 1 -maxdepth 1 -type d \
    ! -name bin ! -name templates -exec cp -a {} "$themes_dir/" \;
cp -a "$source_dir/templates/." "$templates_dir/"
find "$themes_dir" -type f -name colors.toml \
    -exec sed -i "s|/home/usuario|$HOME|g" {} +

install -Dm755 "$source_dir/bin/theme-apply.sh" "$bin_dir/theme-apply"
install -Dm755 "$source_dir/bin/theme-switcher.sh" "$bin_dir/theme-switcher"
install -Dm644 "$source_dir/nord/wallpaper.jpg" \
    "$backgrounds_dir/omarchy-nord-0-black-moon.jpg"

cat > "$bin_dir/power-menu" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
choice=$(printf '%s\n' 'Bloquear' 'Cerrar sesion' 'Suspender' 'Hibernar' 'Reiniciar' 'Apagar' 'Cancelar' | rofi -dmenu -i -p 'Sesion') || exit 0
confirm() { printf '%s\n' 'No' 'Si' | rofi -dmenu -i -p "$1" | grep -qx 'Si'; }
case "$choice" in
    Bloquear) hyprlock ;;
    'Cerrar sesion') confirm 'Cerrar sesion?' && hyprctl dispatch exit ;;
    Suspender) confirm 'Suspender el equipo?' && systemctl suspend ;;
    Hibernar) confirm 'Hibernar el equipo?' && systemctl hibernate ;;
    Reiniciar) confirm 'Reiniciar el equipo?' && systemctl reboot ;;
    Apagar) confirm 'Apagar el equipo?' && systemctl poweroff ;;
esac
SCRIPT
chmod 755 "$bin_dir/power-menu"

cat > "$bin_dir/confirm-close-window" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
answer=$(printf '%s\n' 'No' 'Si' | rofi -dmenu -i -p 'Cerrar la ventana activa?') || exit 0
[[ $answer == 'Si' ]] && hyprctl dispatch killactive
SCRIPT
chmod 755 "$bin_dir/confirm-close-window"

cat > "$bin_dir/render-lockscreen" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
config_dir="$HOME/.config/hypr/lockscreen"
mode=$(cat "$config_dir/mode" 2>/dev/null || printf 'text')
position=$(cat "$config_dir/position" 2>/dev/null || printf 'right')
message_file="$config_dir/message"
image="$HOME/.local/share/hyprlock/company-signature.png"
image_size=$(cat "$config_dir/image-size" 2>/dev/null || printf '320')
output="$HOME/.config/hypr/hyprlock.conf"

[[ $image_size =~ ^[0-9]+$ ]] || image_size=320
(( image_size >= 160 && image_size <= 800 )) || image_size=320

case "$position" in
    left) halign=left; x=55; fortune_halign=right; fortune_x=-55 ;;
    center) halign=center; x=0; fortune_halign=center; fortune_x=0 ;;
    *) halign=right; x=-55; fortune_halign=left; fortune_x=55 ;;
esac

lines=$(wc -l < "$message_file" 2>/dev/null || printf '1')
if (( lines <= 3 )); then font_size=24
elif (( lines <= 6 )); then font_size=20
else font_size=16
fi

cat > "$output" <<CONF
general {
    hide_cursor = true
    immediate_render = true
    text_trim = true
}
background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 7
}
label {
    monitor =
    text = cmd[update:1000] date +"%I:%M %p"
    font_family = JetBrainsMono Nerd Font
    font_size = 72
    color = rgb(216, 222, 233)
    position = 0, 200
    halign = center
    valign = center
}
label {
    monitor =
    text = cmd[update:60000] date +"%d-%m-%Y"
    font_family = JetBrainsMono Nerd Font
    font_size = 24
    color = rgb(216, 222, 233)
    position = 0, 135
    halign = center
    valign = center
}
input-field {
    monitor =
    size = 320, 52
    outline_thickness = 2
    outer_color = rgb(129, 161, 193)
    inner_color = rgb(46, 52, 64)
    font_color = rgb(216, 222, 233)
    placeholder_text = Contraseña
    position = 0, -40
    halign = center
    valign = center
}
CONF

add_image() {
    [[ -f "$image" ]] || return 0
    cat >> "$output" <<CONF
image {
    monitor =
    path = $image
    size = $image_size
    rounding = 0
    border_size = 0
    position = $x, 45
    halign = $halign
    valign = bottom
}
CONF
}
add_text() {
    cat >> "$output" <<CONF
label {
    monitor =
    text = cmd[update:1000] $HOME/.local/bin/lockscreen-content text
    font_family = JetBrainsMono Nerd Font
    font_size = $font_size
    color = rgb(129, 161, 193)
    position = $x, 45
    halign = $halign
    valign = bottom
}
CONF
}
add_fortune() {
    cat >> "$output" <<CONF
label {
    monitor =
    text = cmd[update:30000] $HOME/.local/bin/lockscreen-content fortune
    font_family = JetBrainsMono Nerd Font
    font_size = 16
    color = rgb(236, 239, 244)
    position = 0, 70
    halign = center
    valign = center
}
CONF
}
case "$mode" in
    image) add_image ;;
    text) add_text ;;
    fortune) add_fortune ;;
    image-fortune) add_image; add_fortune ;;
    text-fortune) add_text; add_fortune ;;
    hidden) ;;
esac
SCRIPT
chmod 755 "$bin_dir/render-lockscreen"

cat > "$bin_dir/lockscreen-content" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
mode="${1:-text}"
file="$HOME/.config/hypr/lockscreen/message"
custom_db="$HOME/.local/share/fortune/freddy-es"
if [[ $mode == fortune ]] && command -v fortune >/dev/null 2>&1; then
    if [[ -f $custom_db && -f ${custom_db}.dat ]]; then
        fortune -s "$custom_db" | head -n 6
    else
        fortune -s | head -n 6
    fi
else
    cat "$file" 2>/dev/null || printf 'CachyOS\n'
fi
SCRIPT
chmod 755 "$bin_dir/lockscreen-content"

cat > "$bin_dir/lockscreen-settings" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
config_dir="$HOME/.config/hypr/lockscreen"
message_file="$config_dir/message"
mkdir -p "$config_dir"
edit_text() {
    local action line
    while true; do
        action=$(printf '%s\n' 'Agregar linea' 'Borrar ultima linea' 'Vaciar firma' 'Volver' | rofi -dmenu -i -p 'Editar firma') || return 0
        case "$action" in
            'Agregar linea') line=$(printf '' | rofi -dmenu -p 'Nueva linea') || continue; [[ -n $line ]] && printf '%s\n' "$line" >> "$message_file" ;;
            'Borrar ultima linea') [[ -f $message_file ]] && sed -i '$d' "$message_file" ;;
            'Vaciar firma') : > "$message_file" ;;
            Volver) return 0 ;;
        esac
    done
}
while true; do
    mode=$(cat "$config_dir/mode" 2>/dev/null || printf 'text')
    position=$(cat "$config_dir/position" 2>/dev/null || printf 'right')
    image_size=$(cat "$config_dir/image-size" 2>/dev/null || printf '320')
    prompt="Bloqueo [$mode | $position | ${image_size}px]"
    choice=$(printf '%s\n' 'Firma grafica + Fortune' 'Firma grafica solamente' 'Firma de texto + Fortune' 'Firma de texto solamente' 'Fortune solamente' 'Editar texto' 'Cambiar posicion' 'Cambiar tamaño de imagen' 'Ocultar todo' 'Vista previa' 'Salir' | rofi -dmenu -i -p "$prompt") || exit 0
    case "$choice" in
        'Firma grafica + Fortune') [[ -f "$HOME/.local/share/hyprlock/company-signature.png" ]] || { notify-send 'Hyprlock' 'No se encontro la firma privada'; continue; }; printf 'image-fortune\n' > "$config_dir/mode" ;;
        'Firma grafica solamente') [[ -f "$HOME/.local/share/hyprlock/company-signature.png" ]] || { notify-send 'Hyprlock' 'No se encontro la firma privada'; continue; }; printf 'image\n' > "$config_dir/mode" ;;
        'Firma de texto + Fortune') printf 'text-fortune\n' > "$config_dir/mode" ;;
        'Firma de texto solamente') printf 'text\n' > "$config_dir/mode" ;;
        'Fortune solamente') printf 'fortune\n' > "$config_dir/mode" ;;
        'Editar texto') edit_text ;;
        'Cambiar posicion') position=$(printf '%s\n' 'left' 'center' 'right' | rofi -dmenu -i -p 'Posicion de la firma') || continue; [[ -n $position ]] && printf '%s\n' "$position" > "$config_dir/position" ;;
        'Cambiar tamaño de imagen')
            size_choice=$(printf '%s\n' 'Pequeña (240)' 'Mediana (320)' 'Grande (420)' 'Personalizada' | rofi -dmenu -i -p 'Tamaño de la firma') || continue
            case "$size_choice" in
                'Pequeña (240)') image_size=240 ;; 'Mediana (320)') image_size=320 ;; 'Grande (420)') image_size=420 ;;
                Personalizada) image_size=$(printf '' | rofi -dmenu -p 'Tamaño entre 160 y 800') || continue; [[ $image_size =~ ^[0-9]+$ ]] || { notify-send 'Hyprlock' 'Tamaño inválido'; continue; }; (( image_size >= 160 && image_size <= 800 )) || { notify-send 'Hyprlock' 'Usa un valor entre 160 y 800'; continue; } ;;
                *) continue ;;
            esac
            printf '%s\n' "$image_size" > "$config_dir/image-size" ;;
        'Ocultar todo') printf 'hidden\n' > "$config_dir/mode" ;;
        'Vista previa') "$HOME/.local/bin/render-lockscreen"; hyprlock ;;
        Salir) exit 0 ;;
        *) continue ;;
    esac
    "$HOME/.local/bin/render-lockscreen"
    notify-send 'Hyprlock' 'Configuracion actualizada'
done
SCRIPT
chmod 755 "$bin_dir/lockscreen-settings"

[[ -f "$lock_dir/message" ]] || printf '%s\n' 'CachyOS' > "$lock_dir/message"
[[ -f "$lock_dir/mode" ]] || { [[ -f "$private_signature" ]] && printf 'image\n' || printf 'text\n'; } > "$lock_dir/mode"
[[ -f "$lock_dir/position" ]] || printf 'right\n' > "$lock_dir/position"
[[ -f "$lock_dir/image-size" ]] || printf '320\n' > "$lock_dir/image-size"

"$bin_dir/render-lockscreen"
"$bin_dir/theme-apply" nord
ok "Apariencia, firma y controles instalados"
