#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HYPRLAND_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
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
mkdir -p "$themes_dir" "$current_dir" "$templates_dir" "$backgrounds_dir" "$bin_dir" "$HOME/.config/hypr"
find "$source_dir" -mindepth 1 -maxdepth 1 -type d ! -name bin ! -name templates -exec cp -a {} "$themes_dir/" \;
cp -a "$source_dir/templates/." "$templates_dir/"
find "$themes_dir" -type f -name colors.toml -exec sed -i "s|/home/usuario|$HOME|g" {} +
install -Dm755 "$source_dir/bin/theme-apply.sh" "$bin_dir/theme-apply"
install -Dm755 "$source_dir/bin/theme-switcher.sh" "$bin_dir/theme-switcher"
install -Dm644 "$source_dir/nord/wallpaper.jpg" "$backgrounds_dir/omarchy-nord-0-black-moon.jpg"

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

message_file="$HOME/.config/hypr/lockscreen-message"
[[ -f "$message_file" ]] || printf '%s\n' 'CachyOS' > "$message_file"
cat > "$bin_dir/lockscreen-message" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
file="$HOME/.config/hypr/lockscreen-message"
current=$(cat "$file" 2>/dev/null || printf 'CachyOS')
value=$(printf '%s' "$current" | rofi -dmenu -p 'Texto de la pantalla de bloqueo') || exit 0
[[ -n $value ]] && printf '%s\n' "$value" > "$file"
SCRIPT
chmod 755 "$bin_dir/lockscreen-message"

cat > "$HOME/.config/hypr/hyprlock.conf" <<'CONF'
general {
    hide_cursor = true
    immediate_render = true
}
background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 7
}
label {
    monitor =
    text = cmd[update:1000] date +"%H:%M"
    font_family = JetBrainsMono Nerd Font
    font_size = 72
    color = rgb(216, 222, 233)
    position = 0, 180
    halign = center
    valign = center
}
label {
    monitor =
    text = cmd[update:1000] cat "$HOME/.config/hypr/lockscreen-message"
    font_family = JetBrainsMono Nerd Font
    font_size = 24
    color = rgb(129, 161, 193)
    position = 0, 90
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
    position = 0, -20
    halign = center
    valign = center
}
CONF

"$bin_dir/theme-apply" nord
ok "Apariencia y controles instalados"
