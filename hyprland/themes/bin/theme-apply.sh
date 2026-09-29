#!/usr/bin/env bash
set -Eeuo pipefail

THEME="${1:-$(cat "$HOME/.config/omarchy/current/theme" 2>/dev/null || printf 'nord')}"
THEMES_DIR="$HOME/.config/omarchy/themes"
CURRENT_DIR="$HOME/.config/omarchy/current"
TEMPLATES_DIR="$HOME/.local/share/omarchy-local/themed"
COLORS_FILE="$THEMES_DIR/$THEME/colors.toml"

[[ -f "$COLORS_FILE" ]] || { printf "Tema '%s' no encontrado: %s\n" "$THEME" "$COLORS_FILE" >&2; exit 1; }
mkdir -p "$CURRENT_DIR" "$HOME/.config/hypr/modules" "$HOME/.config/mako"

value() { grep -m1 -E "^${1}[[:space:]]*=" "$COLORS_FILE" | sed 's/.*=[[:space:]]*"\(.*\)"/\1/'; }
optional() { value "$1" 2>/dev/null || true; }

wallpaper=$(value wallpaper)
accent=$(value accent); foreground=$(value foreground); background=$(value background)
selection_foreground=$(value selection_foreground); selection_background=$(value selection_background)
color0=$(value color0); color1=$(value color1); color2=$(value color2); color3=$(value color3)
color4=$(value color4); color5=$(value color5); color6=$(value color6); color7=$(value color7)
color8=$(value color8); color9=$(value color9); color10=$(value color10); color11=$(value color11)
color12=$(value color12); color13=$(value color13); color14=$(value color14); color15=$(value color15)
accent_strip=${accent#\#}; color0_strip=${color0#\#}

sed_args=(
    -e "s|{{ foreground }}|$foreground|g" -e "s|{{ background }}|$background|g"
    -e "s|{{ selection_foreground }}|$selection_foreground|g" -e "s|{{ selection_background }}|$selection_background|g"
    -e "s|{{ color0 }}|$color0|g" -e "s|{{ color1 }}|$color1|g" -e "s|{{ color2 }}|$color2|g" -e "s|{{ color3 }}|$color3|g"
    -e "s|{{ color4 }}|$color4|g" -e "s|{{ color5 }}|$color5|g" -e "s|{{ color6 }}|$color6|g" -e "s|{{ color7 }}|$color7|g"
    -e "s|{{ color8 }}|$color8|g" -e "s|{{ color9 }}|$color9|g" -e "s|{{ color10 }}|$color10|g" -e "s|{{ color11 }}|$color11|g"
    -e "s|{{ color12 }}|$color12|g" -e "s|{{ color13 }}|$color13|g" -e "s|{{ color14 }}|$color14|g" -e "s|{{ color15 }}|$color15|g"
)
sed "${sed_args[@]}" "$TEMPLATES_DIR/alacritty-colors.toml.tpl" > "$CURRENT_DIR/alacritty-colors.toml"
sed -e "s|{{ foreground }}|$foreground|g" -e "s|{{ background }}|$background|g" \
    -e "s|{{ mantle }}|$background|g" -e "s|{{ accent }}|$accent|g" -e "s|{{ color1 }}|$color1|g" \
    "$TEMPLATES_DIR/waybar-colors.css.tpl" > "$CURRENT_DIR/waybar-colors.css"

cat > "$HOME/.config/hypr/modules/appearance.lua" <<LUA
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        layout = "dwindle",
        col = {
            active_border = "rgba(${accent_strip}ee)",
            inactive_border = "rgba(${color0_strip}aa)",
        },
    },
    decoration = {
        rounding = 10,
        blur = { enabled = true, size = 3, passes = 1 },
    },
    animations = { enabled = true },
    misc = { force_default_wallpaper = -1, disable_hyprland_logo = true },
})
LUA

cat > "$HOME/.config/mako/config" <<MAKO
font=JetBrainsMono Nerd Font 12
background-color=$background
text-color=$foreground
border-color=$accent
border-size=2
border-radius=8
default-timeout=5000
width=320
margin=10
padding=15
MAKO

gtk_theme=$(optional gtk_theme); cursor_theme=$(optional cursor_theme); icon_theme=$(optional icon_theme); color_scheme=$(optional color_scheme)
[[ -n $gtk_theme ]] && gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" 2>/dev/null || true
[[ -n $cursor_theme ]] && gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme" 2>/dev/null || true
[[ -n $icon_theme ]] && gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null || true
[[ -n $color_scheme ]] && gsettings set org.gnome.desktop.interface color-scheme "$color_scheme" 2>/dev/null || true

printf '%s\n' "$THEME" > "$CURRENT_DIR/theme"

if [[ -n ${WAYLAND_DISPLAY:-} ]]; then
    hyprctl reload >/dev/null 2>&1 || true
    if [[ -f $wallpaper ]]; then
        pkill swaybg 2>/dev/null || true
        nohup swaybg -i "$wallpaper" -m fill >/dev/null 2>&1 &
    fi
fi
printf "Tema '%s' aplicado.\n" "$THEME"
