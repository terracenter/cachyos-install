# Qtile Config - Omarchy Style (Hyprland Parity)
import os
import subprocess
import glob
import urllib.request
import json
import threading
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
    
    # Monitor focus
    Key([mod], "comma", lazy.next_screen(), desc="Move focus to next monitor"),
    Key([mod], "period", lazy.prev_screen(), desc="Move focus to prev monitor"),
    
    # Move windows
    Key([mod, "shift"], "left", lazy.layout.shuffle_left(), lazy.layout.swap_left(), lazy.layout.client_to_previous(), desc="Move window left"),
    Key([mod, "shift"], "right", lazy.layout.shuffle_right(), lazy.layout.swap_right(), lazy.layout.client_to_next(), desc="Move window right"),
    Key([mod, "shift"], "down", lazy.layout.shuffle_down(), desc="Move window down"),
    Key([mod, "shift"], "up", lazy.layout.shuffle_up(), desc="Move window up"),
    
    # Grow windows
    Key([mod, "control"], "left", lazy.layout.grow_left(), lazy.layout.shrink_main(), lazy.layout.decrease_ratio(), desc="Shrink window / Grow left"),
    Key([mod, "control"], "right", lazy.layout.grow_right(), lazy.layout.grow_main(), lazy.layout.increase_ratio(), desc="Grow window right"),
    Key([mod, "control"], "down", lazy.layout.grow_down(), lazy.layout.shrink(), lazy.layout.increase_nmaster(), desc="Shrink window / Grow down"),
    Key([mod, "control"], "up", lazy.layout.grow_up(), lazy.layout.grow(), lazy.layout.decrease_nmaster(), desc="Grow window up"),
    Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
    Key([mod, "shift"], "y", lazy.next_layout(), desc="Cycle window expansion / Layouts"),
    Key([mod, "control"], "m", lazy.spawn(os.path.expanduser("~/.local/bin/qtile-monitor-setup")), desc="Rofi Monitor Setup"),
    
    # Launchers and controls (Omarchy exact match)
    Key([mod], "q", lazy.spawn(terminal), desc="Launch terminal"),
    Key([mod], "space", lazy.spawn(launcher), desc="Launch Rofi"),
    Key([mod], "e", lazy.spawn("nautilus"), desc="Launch file manager"),
    Key([mod, "shift"], "w", lazy.window.kill(), desc="Kill focused window"),
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Toggle fullscreen"),
    Key([mod], "t", lazy.window.toggle_floating(), desc="Toggle floating"),
    Key([mod, "shift"], "t", lazy.spawn(os.path.expanduser("~/.local/bin/theme-switcher")), desc="Theme Switcher"),
    Key([mod, "shift"], "i", lazy.spawn(os.path.expanduser("~/.local/bin/idle-settings")), desc="Idle Settings"),
    Key([mod], "k", lazy.spawn(os.path.expanduser("~/.local/bin/qtile-keyboard-setup")), desc="Keyboard Layout Setup"),
    Key([mod], "slash", lazy.spawn(os.path.expanduser("~/.local/bin/show-keys")), desc="Show keybindings"),
    Key([mod, "control"], "t", lazy.spawn("alacritty -e btop"), desc="System Monitor"),
    
    # System controls
    Key([mod, "control"], "r", lazy.reload_config(), desc="Reload the config"),
    Key([mod, "shift"], "q", lazy.spawn(os.path.expanduser("~/.local/bin/qtile-exit")), desc="Shutdown Menu"),
    Key([mod], "m", lazy.spawn(os.path.expanduser("~/.local/bin/qtile-exit")), desc="Session Menu"),
    Key([mod, "control"], "l", lazy.spawn(os.path.expanduser("~/.local/bin/qtile-lock")), desc="Lock screen"),
    Key([mod, "control"], "v", lazy.spawn("rofi -modi 'clipboard:greenclip print' -show clipboard -run-command '{cmd}'"), desc="Clipboard History"),

    # Multimedia and Brightness (Omarchy standard mappings)
    Key([], "XF86AudioRaiseVolume", lazy.spawn("sh -c 'pamixer -i 5 && dunstify -a Volume -r 2593 -u normal -h int:value:$(pamixer --get-volume) \"Volume: $(pamixer --get-volume)%\"'"), desc="Volume Up"),
    Key([], "XF86AudioLowerVolume", lazy.spawn("sh -c 'pamixer -d 5 && dunstify -a Volume -r 2593 -u normal -h int:value:$(pamixer --get-volume) \"Volume: $(pamixer --get-volume)%\"'"), desc="Volume Down"),
    Key([], "XF86AudioMute", lazy.spawn("sh -c 'pamixer -t && dunstify -a Volume -r 2593 -u normal \"Mute Toggled\"'"), desc="Volume Mute"),
    Key([], "XF86MonBrightnessUp", lazy.spawn("sh -c 'brightnessctl set +10% && dunstify -a Brightness -r 2594 -u normal -h int:value:$(brightnessctl i | grep -oP \"(?<=\\()\\d+(?=%\\))\") \"Brillo: $(brightnessctl i | grep -oP \"(?<=\\()\\d+(?=%\\))\")%\"'"), desc="Brightness Up"),
    Key([], "XF86MonBrightnessDown", lazy.spawn("sh -c 'brightnessctl set 10%- && dunstify -a Brightness -r 2594 -u normal -h int:value:$(brightnessctl i | grep -oP \"(?<=\\()\\d+(?=%\\))\") \"Brillo: $(brightnessctl i | grep -oP \"(?<=\\()\\d+(?=%\\))\")%\"'"), desc="Brightness Down"),
    
    # Screen Recording and Capture (X11 alternatives)
    Key([mod, "shift"], "s", lazy.spawn("simplescreenrecorder"), desc="Screen Recorder UI"),
    Key([], "Print", lazy.spawn("shutter -s -c -e"), desc="Screenshot region to clipboard"),
    Key([mod], "a", lazy.spawn(os.path.expanduser("~/.local/bin/qtile-audio-setup")), desc="Switch audio output"),
]

profile_path = os.path.expanduser("~/.config/qtile/monitor_profile")
monitor_profile = "doble"
if os.path.exists(profile_path):
    with open(profile_path, "r") as f:
        monitor_profile = f.read().strip()

def go_to_group(name):
    def _inner(qtile):
        num_screens = len(qtile.screens)
        if monitor_profile == "unico" or num_screens == 1:
            pass
        else:
            sorted_screens = sorted(qtile.screens, key=lambda s: s.x)
            if monitor_profile == "triple" and num_screens >= 3:
                left_idx = sorted_screens[0].index
                center_idx = sorted_screens[1].index
                right_idx = sorted_screens[2].index
                if name in "1234": qtile.to_screen(left_idx)
                elif name in "5678": qtile.to_screen(center_idx)
                else: qtile.to_screen(right_idx)
            else:
                left_idx = sorted_screens[0].index
                right_idx = sorted_screens[1].index
                if name in "12345":
                    qtile.to_screen(left_idx)
                else:
                    qtile.to_screen(right_idx)
        qtile.groups_map[name].toscreen()
    return _inner

def move_window_to_group(name):
    def _inner(qtile):
        if qtile.current_window:
            qtile.current_window.togroup(name)
        go_to_group(name)(qtile)
    return _inner

groups = [Group(i) for i in "1234567890"]

for i in groups:
    keys.extend(
        [
            Key([mod], i.name, lazy.function(go_to_group(i.name)), desc=f"Switch to group {i.name}"),
            Key([mod, "shift"], i.name, lazy.function(move_window_to_group(i.name)), desc=f"Move focused window to group {i.name}"),
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
            catppuccin["pink"] = dyn.get("magenta", catppuccin["pink"])
            catppuccin["sky"] = dyn.get("cyan", catppuccin["sky"])
    except Exception:
        pass

# Determinar tema actual para elegir set de iconos
theme_name = "catppuccin"
theme_file = os.path.expanduser("~/.config/omarchy/current/theme")
if os.path.isfile(theme_file):
    try:
        with open(theme_file, 'r') as f:
            theme_name = f.read().strip().lower()
    except Exception:
        pass

# Definición de iconos según el tema (Estilo Omarchy)
if theme_name in ["nord", "ethereal", "solitude", "white", "matte-black"]:
    # Estilo Minimalista / Moderno
    icons = {
        "launcher": "󰣇",
        "volume": "󰕾 ",
        "cpu": " ",
        "ram": " ",
        "brightness": "󰃠 ",
        "battery_charge": "󰂄",
        "battery_discharge": " ",
        "battery_empty": " ",
        "battery_full": " ",
        "battery_unknown": " ",
        "night_light_on": "󰖔 ",
        "night_light_off": "󰛨 ",
    }
else:
    # Estilo Fancy / Clásico
    icons = {
        "launcher": "󰣇",
        "volume": " ",
        "cpu": "󰻠 ",
        "ram": "󰘚 ",
        "brightness": "󰖨 ",
        "battery_charge": "󰂄",
        "battery_discharge": "󰁹",
        "battery_empty": "󰂎",
        "battery_full": "󰁹",
        "battery_unknown": "󰂑",
        "night_light_on": "󰖔 ",
        "night_light_off": "󰛨 ",
    }

layouts = [
    layout.MonadTall(margin=10, border_width=2, border_focus=catppuccin["lavender"], border_normal=catppuccin["surface0"]),
    layout.MonadWide(margin=10, border_width=2, border_focus=catppuccin["lavender"], border_normal=catppuccin["surface0"]),
    layout.Max(margin=10, border_width=2, border_focus=catppuccin["lavender"], border_normal=catppuccin["surface0"]),
    layout.Bsp(margin=10, border_width=2, border_focus=catppuccin["lavender"], border_normal=catppuccin["surface0"]),
    layout.Columns(margin=10, border_width=2, border_focus=catppuccin["lavender"], border_normal=catppuccin["surface0"]),
]

widget_defaults = dict(
    font="JetBrainsMono Nerd Font",
    fontsize=14,
    padding=3,
)
extension_defaults = widget_defaults.copy()

class CustomClock(widget.Clock):
    def poll(self):
        text = super().poll()
        if text:
            text = text[0].upper() + text[1:]
            months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
            for m in months:
                if m in text:
                    text = text.replace(m, m.capitalize())
                    break
            text = text.replace("p. m.", "PM").replace("a. m.", "AM")
            text = text.replace("pm", "PM").replace("am", "AM")
        return text

def has_battery():
    return len(glob.glob('/sys/class/power_supply/BAT*')) > 0

def has_backlight():
    return len(glob.glob('/sys/class/backlight/*')) > 0

def get_brightness():
    try:
        out = subprocess.check_output("brightnessctl -m | cut -d, -f4", shell=True).decode().strip()
        if out:
            return f"{icons['brightness']}{out}"
        return ""
    except Exception:
        return ""

def show_battery_status():
    try:
        bat_dirs = glob.glob('/sys/class/power_supply/BAT*')
        if not bat_dirs:
            return
        bat_dir = bat_dirs[0]
        with open(os.path.join(bat_dir, "status"), "r") as f:
            status = f.read().strip()
        with open(os.path.join(bat_dir, "capacity"), "r") as f:
            capacity = f.read().strip()
        status_es = {
            "Charging": "Cargando",
            "Discharging": "Descargando",
            "Full": "Completa",
            "Not charging": "No cargando"
        }.get(status, status)
        msg = f"Estado: {status_es}\nCarga: {capacity}%"
        subprocess.Popen(f'notify-send "Estado de la Batería" "{msg}" -i battery', shell=True)
    except Exception:
        pass

def change_brightness(direction):
    try:
        step = "5%+" if direction == "up" else "5%-"
        subprocess.Popen(f"brightnessctl set {step}", shell=True)
        
        xrandr_out = subprocess.check_output("xrandr --current", shell=True).decode()
        if "HDMI-1 connected" in xrandr_out:
            cache_file = os.path.expanduser("~/.cache/hdmi-brightness-state")
            current = 1.0
            if os.path.exists(cache_file):
                with open(cache_file, "r") as f:
                    try:
                        current = float(f.read().strip())
                    except ValueError:
                        pass
            
            if direction == "up":
                new_val = min(1.0, current + 0.05)
            else:
                new_val = max(0.2, current - 0.05)
                
            with open(cache_file, "w") as f:
                f.write(f"{new_val:.2f}")
                
            subprocess.Popen(f"xrandr --output HDMI-1 --brightness {new_val:.2f}", shell=True)
    except Exception:
        pass

import time

# Determinar estado inicial de Redshift al cargar la configuración
try:
    res = subprocess.run("pgrep -x redshift", shell=True)
    redshift_active = (res.returncode == 0)
except Exception:
    redshift_active = False

redshift_state = {"active": redshift_active}
last_toggle_time = [0.0]

def get_night_light_status():
    if redshift_state["active"]:
        return icons["night_light_on"]
    else:
        return icons["night_light_off"]

def toggle_night_light():
    current_time = time.time()
    if current_time - last_toggle_time[0] < 1.5:
        return
    last_toggle_time[0] = current_time
    
    if redshift_state["active"]:
        redshift_state["active"] = False
        subprocess.Popen("pkill -x redshift; redshift -x", shell=True)
    else:
        redshift_state["active"] = True
        
        def run():
            if not redshift_state["active"]:
                return
            
            # Coordenadas por defecto (Venezuela, Caracas: Lat 10.48, Lon -66.87)
            loc = "10.4873:-66.8738"
            try:
                with urllib.request.urlopen("http://ip-api.com/json", timeout=2) as response:
                    data = json.loads(response.read().decode())
                    if data.get("status") == "success":
                        loc = f"{data['lat']}:{data['lon']}"
            except Exception:
                pass
            
            if not redshift_state["active"]:
                return
            
            # Limpiar procesos fantasma y arrancar redshift
            subprocess.run("pkill -x redshift; redshift -x", shell=True)
            subprocess.Popen(f"redshift -l {loc} -t 6500:4500 &", shell=True)
            
        threading.Thread(target=run, daemon=True).start()

def create_bar(show_systray=False):
    widgets = [
        # Izquierda: Lanzador y Workspaces
        widget.Spacer(length=10),
        widget.TextBox(text=icons["launcher"], foreground=catppuccin["lavender"], fontsize=18, mouse_callbacks={'Button1': lambda: qtile.spawn(launcher)}),
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
        CustomClock(format="%A %d de %B %Y (Día %j, Semana %V) - %I:%M %p", foreground=catppuccin["text"]),
        
        widget.Spacer(length=bar.STRETCH),
        
        # Derecha: Audio, CPU, RAM
        widget.Volume(
            fmt=icons["volume"] + '{}',
            foreground=catppuccin["sky"],
            padding=10,
            get_volume_command="pamixer --get-volume-human",
            volume_up_command="pamixer -i 5",
            volume_down_command="pamixer -d 5",
            mute_command="pamixer -t",
            check_mute_command="pamixer --get-mute",
            check_mute_string="true",
            mouse_callbacks={
                'Button1': lambda: qtile.cmd_spawn(os.path.expanduser('~/.local/bin/qtile-audio-setup')),
                'Button3': lambda: qtile.cmd_spawn('pavucontrol')
            }
        ),
        widget.CPU(format=icons["cpu"] + '{load_percent}%', foreground=catppuccin["yellow"], padding=10, mouse_callbacks={'Button1': lambda: qtile.spawn("alacritty -e btop")}),
        widget.Memory(format=icons["ram"] + '{MemUsed: .0f}{mm}', foreground=catppuccin["green"], padding=10, mouse_callbacks={'Button1': lambda: qtile.spawn("alacritty -e htop")}),
    ]

    if has_backlight():
        widgets.append(
            widget.GenPollText(
                func=get_brightness,
                update_interval=2,
                foreground=catppuccin["peach"],
                padding=10,
                mouse_callbacks={
                    'Button4': lambda: change_brightness("up"),
                    'Button5': lambda: change_brightness("down"),
                }
            )
        )

    widgets.append(
        widget.GenPollText(
            func=get_night_light_status,
            update_interval=1,
            foreground=catppuccin["lavender"],
            padding=10,
            mouse_callbacks={
                'Button1': toggle_night_light,
            }
        )
    )

    if has_battery():
        widgets.append(
            widget.Battery(
                format='{char} {percent:2.0%}',
                charge_char=icons["battery_charge"],
                discharge_char=icons["battery_discharge"],
                empty_char=icons["battery_empty"],
                full_char=icons["battery_full"],
                unknown_char=icons["battery_unknown"],
                foreground=catppuccin["pink"],
                padding=10,
                mouse_callbacks={'Button1': show_battery_status}
            )
        )

    if show_systray:
        widgets.append(widget.Systray(padding=15))
    
    widgets.append(widget.Spacer(length=10))
    
    return bar.Bar(widgets, 32, background=catppuccin["base"], opacity=0.9, margin=0)

def get_screens():
    num_monitors = 1
    try:
        import subprocess
        output = subprocess.check_output("xrandr --query", shell=True).decode()
        num_monitors = output.count(" connected")
    except Exception:
        pass

    if num_monitors >= 2:
        # Tray en el monitor externo (pantalla 1)
        return [
            Screen(top=create_bar(show_systray=False)),
            Screen(top=create_bar(show_systray=True)),
            Screen(top=create_bar(show_systray=False)), # Para la TV
        ]
    else:
        # Tray en el monitor de la laptop (pantalla 0)
        return [
            Screen(top=create_bar(show_systray=True)),
            Screen(top=create_bar(show_systray=False)),
            Screen(top=create_bar(show_systray=False)), # Para la TV
        ]

screens = get_screens()

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
    if os.path.exists(home):
        try:
            subprocess.call([home])
        except Exception:
            pass

@hook.subscribe.startup_complete
def initial_workspaces():
    from libqtile import qtile
    num_screens = len(qtile.screens)
    
    if num_screens == 1:
        qtile.to_screen(0)
        qtile.groups_map["1"].toscreen()
        return

    sorted_screens = sorted(qtile.screens, key=lambda s: s.x)
    left_idx = sorted_screens[0].index
    right_idx = sorted_screens[1].index
    
    qtile.to_screen(left_idx)
    qtile.groups_map["1"].toscreen()
    
    qtile.to_screen(right_idx)
    qtile.groups_map["6"].toscreen()
    
    if num_screens >= 3:
        tv_idx = sorted_screens[2].index
        qtile.to_screen(tv_idx)
        qtile.groups_map["9"].toscreen()
        
    qtile.to_screen(right_idx)
