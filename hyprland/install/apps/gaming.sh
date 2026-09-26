# Módulo: Instalación de Gaming (Nativo + Cloud)
# Combina optimizaciones nativas de CachyOS con las apps extra de Omarchy.

echo "==> Configurando Gaming (lib32, Steam, Proton, RetroArch, Cloud)..."

# 1. Habilitar multilib
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    sudo pacman -Sy --noconfirm
fi

# 2. Instalar paquetes base (Vulkan/mesa) lib32
gpus=$(lspci | grep -i vga || true)
pkgs=(lib32-mesa)
[[ $gpus =~ "NVIDIA" ]] && pkgs+=(lib32-nvidia-utils)
[[ $gpus =~ "Radeon" ]] && pkgs+=(lib32-vulkan-radeon)
[[ $gpus =~ "Intel" ]]  && pkgs+=(lib32-vulkan-intel)

sudo pacman -S --needed --noconfirm "${pkgs[@]}"

# 3. Herramientas Core de Gaming (Optimizaciones y Launchers nativos)
sudo pacman -S --needed --noconfirm steam wine-staging winetricks lutris moonlight-qt bluez bluez-utils
paru -S --needed --noconfirm gamemode mangohud protonup-qt heroic-games-launcher-bin retroarch

# 4. Configurar Grupo Gamemode
if ! groups "$USER" | grep -qw gamemode; then
    sudo usermod -aG gamemode "$USER"
fi

# 5. Configurar MangoHud
MANGODIR="$HOME/.config/MangoHud"
mkdir -p "$MANGODIR"
cat > "$MANGODIR/MangoHud.conf" << 'MANGOCFG'
fps
gpu_stats
gpu_temp
cpu_stats
cpu_temp
ram
vram
frame_timing=0
position=top-left
font_size=20
background_alpha=0.5
MANGOCFG

# 6. Wrapper de Steam para Hyprland (Evitar doble instancia)
sudo tee /usr/local/bin/steam-launch > /dev/null << 'WRAPPER'
#!/bin/bash
if hyprctl clients -j 2>/dev/null | grep -q '"class": "steam"'; then
    hyprctl dispatch focuswindow class:steam
else
    exec /usr/bin/steam "$@"
fi
WRAPPER
sudo chmod +x /usr/local/bin/steam-launch

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/steam.desktop" << 'DESK'
[Desktop Entry]
Name=Steam
Comment=Plataforma de juegos Steam (Wrapper Hyprland)
Exec=steam-launch %U
Icon=steam
Terminal=false
Type=Application
Categories=Game;
MimeType=x-scheme-handler/steam;
StartupWMClass=steam
DESK

# 7. Cloud Gaming (Web Wrappers de Omarchy)
cat > "$HOME/.local/share/applications/xbox-cloud.desktop" << 'XBOX'
[Desktop Entry]
Name=Xbox Cloud Gaming
Exec=google-chrome-stable --app=https://www.xbox.com/play
Icon=xbox
Type=Application
Categories=Game;
XBOX

cat > "$HOME/.local/share/applications/geforce-now.desktop" << 'GFN'
[Desktop Entry]
Name=NVIDIA GeForce NOW
Exec=google-chrome-stable --app=https://play.geforcenow.com
Icon=nvidia
Type=Application
Categories=Game;
GFN

echo "==> Módulo de Gaming finalizado."
