# Qtile Config - Omarchy Style (Hyprland Parity)
import os
import subprocess
from libqtile import bar, layout, qtile, widget, hook
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy

mod = "mod4"
terminal = "alacritty"
launcher = "rofi -show drun"

keys = [
    # Window focus (Omarchy style with Arrows)
    Key([mod], "left", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "right", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "down", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "up", lazy.layout.up(), desc="Move focus up"),
    
    # Move windows
    Key([mod, "shift"], "left", lazy.layout.shuffle_left(), desc="Move window to the left"),
    Key([mod, "shift"], "right", lazy.layout.shuffle_right(), desc="Move window to the right"),
    Key([mod, "shift"], "down", lazy.layout.shuffle_down(), desc="Move window down"),
    Key([mod, "shift"], "up", lazy.layout.shuffle_up(), desc="Move window up"),
    
    # Grow windows
    Key([mod, "control"], "left", lazy.layout.grow_left(), desc="Grow window to the left"),
    Key([mod, "control"], "right", lazy.layout.grow_right(), desc="Grow window to the right"),
    Key([mod, "control"], "down", lazy.layout.grow_down(), desc="Grow window down"),
    Key([mod, "control"], "up", lazy.layout.grow_up(), desc="Grow window up"),
    Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
    
    # Launchers and controls (Omarchy exact match)
    Key([mod], "q", lazy.spawn(terminal), desc="Launch terminal"),
    Key([mod], "space", lazy.spawn("rofi -show drun -show-icons"), desc="Launcher"),
    Key([mod], "e", lazy.spawn("nautilus"), desc="Launch file manager"),    # Switch between windows
    Key([mod], "h", lazy.layout.left(), desc="Move focus to left"),
    Key([mod], "l", lazy.layout.right(), desc="Move focus to right"),
    Key([mod], "j", lazy.layout.down(), desc="Move focus down"),
    Key([mod], "k", lazy.layout.up(), desc="Move focus up"),
    Key(["mod1"], "Tab", lazy.layout.next(), desc="Move window focus to other window"),

    # Move windows
    Key([mod, "shift"], "h", lazy.layout.shuffle_left(), desc="Move window to the left"),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right(), desc="Move window to the right"),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Move window down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),
    Key([mod, "shift"], "Left", lazy.layout.shuffle_left(), desc="Move window left"),
    Key([mod, "shift"], "Right", lazy.layout.shuffle_right(), desc="Move window right"),
    Key([mod, "shift"], "Up", lazy.layout.shuffle_up(), desc="Move window up"),
    Key([mod, "shift"], "Down", lazy.layout.shuffle_down(), desc="Move window down"),

    # Toggle between split and unsplit sides of stack.
    Key([mod, "shift"], "Return", lazy.layout.toggle_split(), desc="Toggle between split and unsplit"),
    Key([mod], "Return", lazy.spawn(terminal), desc="Launch terminal"),
    Key([mod], "q", lazy.spawn(terminal), desc="Launch terminal"),
    Key([mod], "e", lazy.spawn("nautilus"), desc="File Manager"),

    # Window Controls
    Key([mod, "shift"], "w", lazy.window.kill(), desc="Kill focused window"),
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Toggle fullscreen"),
    Key([mod, "mod1"], "f", lazy.window.toggle_maximize(), desc="Toggle maximized"),
    Key([mod], "t", lazy.window.toggle_floating(), desc="Toggle floating"),
    Key([mod], "p", lazy.window.toggle_floating(), desc="Toggle floating (Pseudo)"),
    
    # Custom Omarchy Scripts / Apps
    Key([mod, "shift"], "t", lazy.spawn(os.path.expanduser("~/.local/bin/theme-switcher")), desc="Theme Switcher"),
    Key([mod, "shift"], "i", lazy.spawn(os.path.expanduser("~/.local/bin/idle-settings")), desc="Idle Settings"),
    Key([mod, "shift"], "y", lazy.spawn("sh -c 'if pgrep -x eww; then pkill -x eww; else eww open sysmon; fi'"), desc="Toggle Sysmon"),
    Key([mod, "control"], "t", lazy.spawn("alacritty -e btop"), desc="System Monitor"),
    Key([mod, "control"], "w", lazy.spawn("alacritty -e nmtui"), desc="Network Manager UI"),
    Key([mod, "control"], "b", lazy.spawn("blueman-manager"), desc="Bluetooth Manager"),
    Key([mod, "control"], "a", lazy.spawn("alacritty -e wiremix"), desc="Audio Mixer"),
    Key([mod, "control"], "v", lazy.spawn("bash -c 'cliphist list | rofi -dmenu -p Portapapeles | cliphist decode | xclip -selection clipboard'"), desc="Clipboard"),
    
    # System controls
    Key([mod, "control"], "r", lazy.reload_config(), desc="Reload the config"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Shutdown Qtile"),
    Key([mod], "r", lazy.spawncmd(), desc="Spawn a command using a prompt widget"),
    Key([mod, "control"], "l", lazy.spawn("i3lock-color --blur 7 --clock --indicator --ring-color=b4befe --inside-color=1e1e2e --text-color=cdd6f4"), desc="Lock screen"),
    Key([mod, "shift"], "space", lazy.hide_show_bar("top"), desc="Toggle Bar"),

    # Dunst Notifications
    Key([mod], "comma", lazy.spawn("dunstctl close"), desc="Close Notification"),
    Key([mod, "shift"], "comma", lazy.spawn("dunstctl close-all"), desc="Close All Notifications"),

    # Multimedia and Brightness
    Key([], "XF86AudioRaiseVolume", lazy.spawn("sh -c 'pamixer -i 5 && dunstify -a Volume -r 2593 -u normal -h int:value:$(pamixer --get-volume) \"Volume: $(pamixer --get-volume)%\"'"), desc="Volume Up"),
    Key([], "XF86AudioLowerVolume", lazy.spawn("sh -c 'pamixer -d 5 && dunstify -a Volume -r 2593 -u normal -h int:value:$(pamixer --get-volume) \"Volume: $(pamixer --get-volume)%\"'"), desc="Volume Down"),
    Key([], "XF86AudioMute", lazy.spawn("sh -c 'pamixer -t && dunstify -a Volume -r 2593 -u normal \"Mute Toggled\"'"), desc="Volume Mute"),
    Key([], "XF86AudioMicMute", lazy.spawn("sh -c 'pamixer --default-source -t && dunstify -a Mic -r 2594 -u normal \"Mic Mute Toggled\"'"), desc="Mic Mute"),
    Key([], "XF86MonBrightnessUp", lazy.spawn("sh -c 'brightnessctl set +10% && dunstify -a Brightness -r 2595 -u normal -h int:value:$(brightnessctl i | grep -oP \"(?<=\\()\\d+(?=%\\))\") \"Brillo: $(brightnessctl i | grep -oP \"(?<=\\()\\d+(?=%\\))\")%\"'"), desc="Brightness Up"),
    Key([], "XF86MonBrightnessDown", lazy.spawn("sh -c 'brightnessctl set 10%- && dunstify -a Brightness -r 2595 -u normal -h int:value:$(brightnessctl i | grep -oP \"(?<=\\()\\d+(?=%\\))\") \"Brillo: $(brightnessctl i | grep -oP \"(?<=\\()\\d+(?=%\\))\")%\"'"), desc="Brightness Down"),
    Key([], "XF86AudioNext", lazy.spawn("playerctl next"), desc="Next Track"),
    Key([], "XF86AudioPause", lazy.spawn("playerctl play-pause"), desc="Play/Pause"),
    Key([], "XF86AudioPlay", lazy.spawn("playerctl play-pause"), desc="Play/Pause"),
    Key([], "XF86AudioPrev", lazy.spawn("playerctl previous"), desc="Previous Track"),
    
    # Screen Recording and Capture (X11 alternatives)
    Key([mod, "shift"], "s", lazy.spawn("gpu-screen-recorder-gtk"), desc="Screen Recorder UI"),
    Key([], "Print", lazy.spawn("sh -c 'maim -s | xclip -selection clipboard -t image/png'"), desc="Screenshot region to clipboard"),
]

groups = [Group(i) for i in "123456789"]

for i in groups:
    keys.extend(
        [
            Key([mod], i.name, lazy.group[i.name].toscreen(), desc=f"Switch to group {i.name}"),
            Key([mod, "shift"], i.name, lazy.window.togroup(i.name, switch_group=True), desc=f"Move focused window to group {i.name}"),
        ]
    )

# Colores Catppuccin Mocha
import json
import os

catppuccin = {
    "rosewater": "#f5e0dc", "flamingo": "#f2cdcd", "pink": "#f5c2e7",
    "mauve": "#cba6f7", "red": "#f38ba8", "maroon": "#eba0ac",
    "peach": "#fab387", "yellow": "#f9e2af", "green": "#a6e3a1",
    "teal": "#94e2d5", "sky": "#89dceb", "sapphire": "#74c7ec",
    "blue": "#89b4fa", "lavender": "#b4befe", "text": "#cdd6f4",
    "subtext1": "#bac2de", "subtext0": "#a6adc8", "overlay2": "#9399b2",
    "overlay1": "#7f849c", "overlay0": "#6c7086", "surface2": "#585b70",
    "surface1": "#45475a", "surface0": "#313244", "base": "#1e1e2e",
    "mantle": "#181825", "crust": "#11111b",
}

colors_file = os.path.expanduser("~/.config/omarchy/current/qtile-colors.json")
if os.path.isfile(colors_file):
    try:
        with open(colors_file, 'r') as f:
            dyn = json.load(f)
            # Map dynamic colors to the catppuccin keys used in the config
            catppuccin["base"] = dyn.get("background", catppuccin["base"])
            catppuccin["text"] = dyn.get("foreground", catppuccin["text"])
            catppuccin["lavender"] = dyn.get("accent", catppuccin["lavender"])
            catppuccin["surface0"] = dyn.get("surface", catppuccin["surface0"])
            catppuccin["surface1"] = dyn.get("surface", catppuccin["surface1"])
            catppuccin["blue"] = dyn.get("blue", catppuccin["blue"])
            catppuccin["red"] = dyn.get("red", catppuccin["red"])
            catppuccin["green"] = dyn.get("green", catppuccin["green"])
            catppuccin["yellow"] = dyn.get("yellow", catppuccin["yellow"])
            catppuccin["peach"] = dyn.get("yellow", catppuccin["peach"])
    except Exception:
        pass

layouts = [
    layout.MonadTall(margin=10, border_width=2, border_focus=catppuccin["lavender"], border_normal=catppuccin["surface0"]),
    layout.Max(),
    layout.Bsp(margin=10, border_width=2, border_focus=catppuccin["lavender"], border_normal=catppuccin["surface0"]),
]

widget_defaults = dict(
    font="JetBrainsMono Nerd Font",
    fontsize=14,
    padding=3,
)
extension_defaults = widget_defaults.copy()

screens = [
    Screen(
        top=bar.Bar(
            [
                # Izquierda: Lanzador y Workspaces
                widget.Spacer(length=10),
                widget.TextBox(text="󰣇", foreground=catppuccin["blue"], fontsize=18, mouse_callbacks={'Button1': lambda: qtile.cmd_spawn(launcher)}),
                widget.Spacer(length=15),
                widget.GroupBox(
                    active=catppuccin["text"],
                    inactive=catppuccin["surface1"],
                    highlight_color=[catppuccin["base"], catppuccin["base"]],
                    highlight_method="line",
                    this_current_screen_border=catppuccin["lavender"],
                    margin_y=3,
                    padding_y=5,
                    padding_x=6,
                    borderwidth=3,
                    disable_drag=True
                ),
                widget.Spacer(length=bar.STRETCH),
                
                # Centro: Reloj
                widget.Clock(format="%A %H:%M", foreground=catppuccin["text"]),
                
                widget.Spacer(length=bar.STRETCH),
                
                # Derecha: Bluetooth, Audio, Brillo, CPU, Batería, Bandeja
                widget.Bluetooth(fmt='󰂱 {}', foreground=catppuccin["blue"], padding=10),
                widget.PulseVolume(fmt='󰕿 {}', foreground=catppuccin["text"], padding=10),
                widget.Backlight(backlight_name='intel_backlight', format='󰃠 {percent:2.0%}', foreground=catppuccin["text"], padding=10),
                widget.CPU(format='󰍛 {load_percent}%', foreground=catppuccin["peach"], padding=10),
                widget.Battery(format='{char} {percent:2.0%}', charge_char='󰂄', discharge_char='󰁹', foreground=catppuccin["green"], padding=10),
                widget.Systray(padding=15),
                widget.Spacer(length=10),
            ],
            32,
            background=catppuccin["base"],
            opacity=0.9,
            margin=[10, 10, 0, 10]
        ),
    ),
]

mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

floating_layout = layout.Floating(
    float_rules=[
        *layout.Floating.default_float_rules,
        Match(wm_class="confirmreset"),
        Match(wm_class="makebranch"),
        Match(wm_class="maketag"),
        Match(wm_class="ssh-askpass"),
        Match(title="branchdialog"),
        Match(title="pinentry"),
    ],
    border_width=2,
    border_focus=catppuccin["red"],
    border_normal=catppuccin["surface0"]
)

dgroups_key_binder = None
dgroups_app_rules = []
follow_mouse_focus = True
bring_front_click = False
floats_kept_above = True
cursor_warp = False
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True
auto_minimize = True
wl_input_rules = None
wmname = "LG3D"

@hook.subscribe.startup_once
def autostart():
    home = os.path.expanduser('~/.config/qtile/autostart.sh')
    subprocess.call([home])
