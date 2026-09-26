#!/bin/bash
# ─── 10b. SDDM Background Switcher ───────────────────────────────────────────
step "Configurando SDDM Background Switcher..."
theme_dir="/usr/share/sddm/themes/sddm-astronaut-theme"
bg_dir="$theme_dir/Backgrounds"

# Helper con privilegios (requerirá clave sudo interactiva)
sudo tee /usr/local/bin/sddm-apply-bg > /dev/null << 'HELPER_EOF'
#!/bin/bash
bg="$1"
conf="/etc/sddm.conf.d/sddm-astronaut-theme.conf"
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

# ─── 10d. GRUB ───────────────────────────────────────────────────────────────
step "Configurando Temas de GRUB Gráfico..."
themes_sys="/usr/share/grub/themes"
sudo mkdir -p "$themes_sys"
tmp=$(mktemp -d)

if git clone --depth 1 https://github.com/catppuccin/grub.git "$tmp/catppuccin" 2>/dev/null; then
    sudo cp -r "$tmp/catppuccin/src/catppuccin-mocha-grub-theme" "$themes_sys/"
    ok "Tema Catppuccin Mocha GRUB instalado"
fi
rm -rf "$tmp"

grub_theme="${themes_sys}/catppuccin-mocha-grub-theme/theme.txt"
if [[ -f "$grub_theme" ]]; then
    sudo sed -i 's|^#\?GRUB_THEME=.*||' /etc/default/grub
    echo "GRUB_THEME=\"$grub_theme\"" | sudo tee -a /etc/default/grub > /dev/null
    sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    ok "GRUB_THEME=catppuccin-mocha-grub-theme configurado y grub.cfg regenerado"
fi

step "Configurando GRUB Theme Switcher..."
sudo tee /usr/local/bin/grub-apply-theme > /dev/null << 'HELPER_EOF'
#!/bin/bash
theme="$1"
[[ -f "$theme" ]] || { echo "ERROR: theme.txt no encontrado: $theme"; exit 1; }
sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$theme\"|" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg \
    && echo "LISTO — tema aplicado: $(basename "$(dirname "$theme")")"
HELPER_EOF
sudo chmod 755 /usr/local/bin/grub-apply-theme
ok "Helper /usr/local/bin/grub-apply-theme creado"

cat > "$HOME/.local/bin/grub-theme-switcher" << 'SWITCHER_EOF'
#!/bin/bash
THEMES_DIR="/usr/share/grub/themes"
selected=$(ls "$THEMES_DIR" | rofi -dmenu -p "Tema GRUB" -i)
[[ -z "$selected" ]] && exit 0
theme="$THEMES_DIR/$selected/theme.txt"
if [[ ! -f "$theme" ]]; then
    notify-send "GRUB Theme Switcher" "theme.txt no encontrado en: $selected"
    exit 1
fi
echo "Aplicando tema: $selected"
sudo /usr/local/bin/grub-apply-theme "$theme"
echo ""
echo "Presiona Enter para cerrar..."
read -r _
SWITCHER_EOF
chmod +x "$HOME/.local/bin/grub-theme-switcher"
ok "Script ~/.local/bin/grub-theme-switcher creado"

cat > "$HOME/.local/share/applications/grub-theme-switcher.desktop" << DESKTOP_EOF
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
DESKTOP_EOF
ok "Entrada GRUB Theme Switcher disponible en rofi"

# ─── 10e. Plymouth (boot splash) ─────────────────────────────────────────────
step "Instalando y configurando Plymouth (boot splash)..."
sudo pacman -S --needed --noconfirm plymouth 2>/dev/null || warn "Plymouth ya instalado o fallo la instalación"
if ! grep -q 'HOOKS.*plymouth' /etc/mkinitcpio.conf 2>/dev/null; then
    sudo sed -i 's/\(HOOKS=([^)]*udev\)/\1 plymouth/' /etc/mkinitcpio.conf
    ok "Hook 'plymouth' añadido a mkinitcpio.conf"
fi

if [[ -f /etc/default/grub ]] && ! grep -q 'splash' /etc/default/grub; then
    sudo sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 quiet splash"/' /etc/default/grub
    ok "Añadido 'quiet splash' a GRUB_CMDLINE_LINUX_DEFAULT"
fi

omarchy_dir="/usr/share/plymouth/themes/omarchy"
if [[ ! -f "$omarchy_dir/omarchy.plymouth" ]]; then
    tmp=$(mktemp -d)
    if git clone --depth 1 https://github.com/basecamp/omarchy.git "$tmp" 2>/dev/null; then
        sudo mkdir -p "$omarchy_dir"
        sudo cp -r "$tmp/default/plymouth/." "$omarchy_dir/"
        ok "Tema Plymouth Omarchy instalado"
    fi
    rm -rf "$tmp"
fi

if [[ -f "$omarchy_dir/omarchy.plymouth" ]]; then
    sudo plymouth-set-default-theme -R omarchy
    ok "Plymouth configurado — tema: omarchy"
else
    sudo plymouth-set-default-theme -R cachyos
    ok "Plymouth configurado — tema: cachyos (fallback)"
fi
