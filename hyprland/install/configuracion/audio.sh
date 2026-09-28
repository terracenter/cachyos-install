#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
HYPRLAND_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd -P)"
source "$HYPRLAND_DIR/install/basico/helpers.sh"
show_script_version "Configuracion de audio" "${BASH_SOURCE[0]}"
[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."
step "Instalando herramientas de audio de Hyprland"
sudo pacman -S --needed --noconfirm pipewire pipewire-audio pipewire-pulse wireplumber pavucontrol jq libnotify swayosd
install -Dm755 "$HYPRLAND_DIR/configs/hypr-audio-setup.sh" "$HOME/.local/bin/hypr-audio-setup"
install -Dm755 "$HYPRLAND_DIR/configs/hypr-audio-volume.sh" "$HOME/.local/bin/hypr-audio-volume"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/hypr-audio-setup.desktop" <<EOF_DESKTOP
[Desktop Entry]
Name=Audio (Hyprland)
GenericName=Mezclador de audio
Comment=Configura salida, microfono y audio por aplicacion
Exec=$HOME/.local/bin/hypr-audio-setup
Icon=audio-card
Terminal=false
Type=Application
Categories=Audio;Settings;
Keywords=audio;sound;output;input;mic;speaker;headphone;
StartupNotify=false
EOF_DESKTOP
ok "Herramientas de audio instaladas"
