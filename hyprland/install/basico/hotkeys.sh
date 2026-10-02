#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/helpers.sh"
show_script_version "Configuracion Lua de Hyprland" "${BASH_SOURCE[0]}"
[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

step "Creando configuracion modular Lua de Hyprland"
config_dir="$HOME/.config/hypr"
modules_dir="$config_dir/modules"
config_file="$config_dir/hyprland.lua"
bin_dir="$HOME/.local/bin"
mkdir -p "$modules_dir" "$bin_dir"
[[ -f "$config_file" ]] && cp -a "$config_file" "${config_file}.bak.$(date +%Y%m%d_%H%M%S)"

cat > "$config_file" <<'LUA'
-- CachyOS Hyprland 0.56+
require("monitors")
require("workspaces")
require("modules/input")
require("modules/appearance")
require("modules/autostart")
require("modules/keybindings")
LUA

cat > "$modules_dir/appearance.lua" <<'LUA'
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.config({
    general = {
        gaps_in = 5, gaps_out = 10, border_size = 2, layout = "dwindle",
        col = { active_border = "rgba(81a1c1ee)", inactive_border = "rgba(4c566aaa)" },
    },
    decoration = { rounding = 10, blur = { enabled = true, size = 3, passes = 1 } },
    animations = { enabled = true },
    dwindle = {
        preserve_split = true,
    },
    misc = { force_default_wallpaper = -1, disable_hyprland_logo = true },
})
LUA

cat > "$modules_dir/autostart.lua" <<'LUA'
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- waybar")
    hl.exec_cmd("uwsm app -- swaync")
    hl.exec_cmd("uwsm app -- nm-applet --indicator")
    hl.exec_cmd("uwsm app -- hypridle")
    hl.exec_cmd("uwsm app -- /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("~/.local/bin/theme-apply")
end)
LUA

cat > "$modules_dir/keybindings.lua" <<'LUA'
local mainMod = "SUPER"
local terminal = "alacritty"
local fileManager = "nautilus"
local menu = "rofi -show drun"

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("~/.local/bin/confirm-close-window"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("~/.local/bin/power-menu"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("~/.local/bin/toggle-window-float"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("~/.local/bin/theme-switcher"))

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Reorganizar ventanas al estilo Omarchy
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.swap({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.swap({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.swap({ direction = "down" }))

-- Alternar orientación de la próxima división Dwindle
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
LUA
cat > "$bin_dir/toggle-window-float" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail

active_window=$(hyprctl activewindow -j)
window_address=$(jq -r '.address // empty' <<< "$active_window")
floating=$(jq -r '.floating // false' <<< "$active_window")

[[ -n "$window_address" ]] || exit 0

if [[ "$floating" == "true" ]]; then
    hyprctl dispatch 'hl.dsp.window.float({ action = "disable" })' >/dev/null
else
    hyprctl dispatch 'hl.dsp.window.float({ action = "enable" })' >/dev/null
    sleep 0.15
    hyprctl dispatch 'hl.dsp.window.resize({ x = 1100, y = 700, relative = false })' >/dev/null
    sleep 0.15
    hyprctl dispatch 'hl.dsp.window.center({})' >/dev/null
fi
SCRIPT
chmod 755 "$bin_dir/toggle-window-float"
ok "Configuracion Lua creada en $config_file"
