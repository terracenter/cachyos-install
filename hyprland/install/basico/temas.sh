#!/bin/bash
# ─── 10b. SDDM Background Switcher ───────────────────────────────────────────
step "Configurando SDDM Background Switcher..."

# Helper con privilegios (requerirá clave sudo interactiva)
sudo tee /usr/local/bin/sddm-apply-bg > /dev/null << 'HELPER_EOF'
#!/bin/bash
bg="$1"
conf="/etc/sddm.conf.d/10-hyprland.conf"
[[ -f "$conf" ]] || { echo "ERROR: $conf no existe"; exit 1; }
[[ -n "$bg" ]]   || { echo "ERROR: nombre de fondo vacío"; exit 1; }
if grep -q '^Background=' "$conf"; then
    sed -i "s|^Background=.*|Background=Backgrounds/$bg|" "$conf"
else
    sed -i '/^\[General\]/a Background=Backgrounds/'"$bg" "$conf"
fi
echo "LISTO — fondo aplicado: $bg"
HELPER_EOF
sudo chmod 755 /usr/local/bin/sddm-apply-bg
ok "Helper /usr/local/bin/sddm-apply-bg creado"

# Script de usuario interactivo
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/sddm-bg-switcher" << 'SWITCHER_EOF'
#!/bin/bash
BG_DIR="/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds"
selected=$(ls "$BG_DIR" | rofi -dmenu -p "Fondo SDDM" -i)
[[ -z "$selected" ]] && exit 0
echo "Aplicando fondo: $selected"
sudo /usr/local/bin/sddm-apply-bg "$selected"
echo ""
echo "Presiona Enter para cerrar..."
read -r _
SWITCHER_EOF
chmod +x "$HOME/.local/bin/sddm-bg-switcher"
ok "Script ~/.local/bin/sddm-bg-switcher creado"

# Entrada .desktop para rofi
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/sddm-bg-switcher.desktop" << DESKTOP_EOF
[Desktop Entry]
Name=SDDM Background Switcher
Comment=Cambiar fondo de pantalla de SDDM
Exec=alacritty -e $HOME/.local/bin/sddm-bg-switcher
Icon=preferences-desktop-wallpaper
Terminal=false
Type=Application
Categories=Settings;
Keywords=sddm;background;wallpaper;
NoDisplay=false
DESKTOP_EOF
ok "Entrada SDDM Background Switcher disponible en rofi"

# Mapeo de fondos omarchy -> sddm
sddm_map="${HOME}/.local/share/omarchy-local/sddm-bg-map"
mkdir -p "$(dirname "$sddm_map")"
cat > "$sddm_map" << 'MAP_EOF'
default=samurai.png
catppuccin=samurai.png
catppuccin-latte=samurai.png
ethereal=bridge.jpg
everforest=samurai.png
flexoki-light=samurai.png
gruvbox=gruvbox.png
hackerman=samurai.png
kanagawa=wave.jpg
last-horizon=samurai.png
lumon=samurai.png
matte-black=samurai.png
miasma=samurai.png
nord=nord.png
osaka-jade=samurai.png
retro-82=retro.png
ristretto=samurai.png
rose-pine=samurai.png
solitude=samurai.png
tokyo-night=samurai.png
vantablack=samurai.png
white=samurai.png
MAP_EOF
ok "sddm-bg-map creado"


# ─── GRUB Theme Switcher ───────────────────────────────────────────────────

step "Configurando GRUB Theme Switcher..."

sudo tee /usr/local/bin/grub-apply-theme > /dev/null << 'HELPER_EOF'
#!/bin/bash

theme="$1"

[[ -f "$theme" ]] || {
    echo "ERROR: theme.txt no encontrado: $theme"
    exit 1
}

sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$theme\"|" /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg \
    && echo "LISTO — tema aplicado: $(basename "$(dirname "$theme")")"
HELPER_EOF

sudo chmod 755 /usr/local/bin/grub-apply-theme

ok "Helper /usr/local/bin/grub-apply-theme creado"

echo "$USER ALL=(root) NOPASSWD: /usr/local/bin/grub-apply-theme" \
    | sudo tee /etc/sudoers.d/grub-theme-switcher > /dev/null

sudo chmod 440 /etc/sudoers.d/grub-theme-switcher

ok "Sudoers configurado para grub-apply-theme"

mkdir -p "$HOME/.local/bin"

cat > "$HOME/.local/bin/grub-theme-switcher" << 'SWITCHER_EOF'
#!/bin/bash

THEMES_DIR="/usr/share/grub/themes"

selected=$(ls "$THEMES_DIR" | rofi -dmenu -p "Tema GRUB" -i)

[[ -z "$selected" ]] && exit 0

theme="$THEMES_DIR/$selected/theme.txt"

if [[ ! -f "$theme" ]]; then
    notify-send "GRUB Theme Switcher" \
        "theme.txt no encontrado en: $selected"
    exit 1
fi

sudo /usr/local/bin/grub-apply-theme "$theme"

echo ""
echo "Presiona Enter para cerrar..."
read -r _
SWITCHER_EOF

chmod +x "$HOME/.local/bin/grub-theme-switcher"

ok "Script ~/.local/bin/grub-theme-switcher creado"

mkdir -p "$HOME/.local/share/applications"

cat > "$HOME/.local/share/applications/grub-theme-switcher.desktop" << EOF
[Desktop Entry]
Name=GRUB Theme Switcher
Comment=Cambiar tema visual del menú GRUB
Exec=alacritty -e $HOME/.local/bin/grub-theme-switcher
Icon=preferences-system-details
Terminal=false
Type=Application
Categories=System;Settings;
Keywords=grub;theme;boot;
NoDisplay=false
EOF

ok "Entrada GRUB Theme Switcher disponible en rofi"

grub_map="${HOME}/.local/share/omarchy-local/grub-theme-map"

mkdir -p "$(dirname "$grub_map")"

cat > "$grub_map" << 'MAP_EOF'
default=catppuccin-mocha-grub-theme
catppuccin=catppuccin-mocha-grub-theme
catppuccin-latte=catppuccin-latte-grub-theme
ethereal=catppuccin-macchiato-grub-theme
everforest=gruvbox
flexoki-light=catppuccin-latte-grub-theme
gruvbox=gruvbox
hackerman=stylish
kanagawa=catppuccin-mocha-grub-theme
last-horizon=tela
lumon=catppuccin-latte-grub-theme
matte-black=stylish
miasma=catppuccin-mocha-grub-theme
nord=nord
osaka-jade=catppuccin-macchiato-grub-theme
retro-82=dracula
ristretto=catppuccin-frappe-grub-theme
rose-pine=dracula
solitude=catppuccin-latte-grub-theme
tokyo-night=catppuccin-mocha-grub-theme
vantablack=stylish
white=catppuccin-latte-grub-theme
MAP_EOF

ok "grub-theme-map creado"