#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/../basico/helpers.sh"

show_script_version "Gestion visual de monitores" "${BASH_SOURCE[0]}"

[[ $EUID -ne 0 ]] || die "Ejecuta este modulo como usuario normal."

step "Instalando gestor visual de monitores"

paru -S --needed --noconfirm nwg-displays \
    || die "No se pudo instalar nwg-displays"

config_dir="$HOME/.config/hypr"
mkdir -p "$config_dir"

monitors_file="$config_dir/monitors.lua"
workspaces_file="$config_dir/workspaces.lua"

if [[ ! -f "$monitors_file" ]]; then
    cat > "$monitors_file" <<'LUA'
-- Configuracion inicial segura.
-- Usa nwg-displays para guardar una distribucion personalizada.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})
LUA
    ok "Configuracion inicial de monitores creada"
else
    ok "Configuracion personalizada de monitores conservada"
fi

if [[ ! -f "$workspaces_file" ]]; then
    cat > "$workspaces_file" <<'LUA'
-- Asignaciones generadas por nwg-displays.
-- Archivo inicialmente vacio para no imponer rangos de workspaces.
LUA
    ok "Archivo inicial de workspaces creado"
else
    ok "Asignaciones personalizadas de workspaces conservadas"
fi

rm -f "$HOME/.local/bin/hypr-monitor-workspaces"

ok "Gestion visual disponible mediante nwg-displays"
info "Organiza las pantallas, asigna workspaces y guarda desde nwg-displays."
