#!/bin/bash
# ─── 10b. SDDM Background Switcher ───────────────────────────────────────────
step "Configurando SDDM Background Switcher..."

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
