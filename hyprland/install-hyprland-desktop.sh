#!/bin/bash
# Instalador Base Minimalista de Hyprland para CachyOS
# Inspirado en la arquitectura modular de Omarchy

set -e

export CACHY_INSTALL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CACHY_LOG="/tmp/cachyos-hyprland-install.log"

run_logged() {
  local script_path="$1"
  if [[ ! -f "$script_path" ]]; then
    echo "ERROR: Módulo no encontrado: $script_path" | tee -a "$CACHY_LOG"
    exit 1
  fi
  echo "==> Ejecutando módulo: $(basename "$script_path")" | tee -a "$CACHY_LOG"
  source "$script_path" 2>&1 | tee -a "$CACHY_LOG"
  if (( PIPESTATUS[0] != 0 )); then
    echo "ERROR: Falló la ejecución del módulo $(basename "$script_path")" | tee -a "$CACHY_LOG"
    exit 1
  fi
}

echo "Iniciando instalación base de Hyprland..." | tee -a "$CACHY_LOG"

source "$CACHY_INSTALL/install/basico/helpers.sh"

# 1. Básicos
run_logged "$CACHY_INSTALL/install/basico/navegacion.sh"
run_logged "$CACHY_INSTALL/install/basico/top-bar.sh"
run_logged "$CACHY_INSTALL/install/basico/temas.sh"
run_logged "$CACHY_INSTALL/install/basico/hotkeys.sh"

# 2. Configuración
run_logged "$CACHY_INSTALL/install/configuracion/updates-paru.sh"
run_logged "$CACHY_INSTALL/install/configuracion/monitores.sh"
run_logged "$CACHY_INSTALL/install/configuracion/teclado-mouse.sh"
run_logged "$CACHY_INSTALL/install/configuracion/firewall-nftable.sh"

# 3. Aplicaciones (Modulares)
run_logged "$CACHY_INSTALL/install/apps/terminal-neovim.sh"
run_logged "$CACHY_INSTALL/install/apps/shell-tools.sh"
run_logged "$CACHY_INSTALL/install/apps/dev-tools.sh"
run_logged "$CACHY_INSTALL/install/apps/vms-pdfs.sh"
run_logged "$CACHY_INSTALL/install/apps/guis.sh"
run_logged "$CACHY_INSTALL/install/apps/navegadores.sh"

# 4. Rest
run_logged "$CACHY_INSTALL/install/rest/seguridad.sh"

echo "Instalación base completada con éxito." | tee -a "$CACHY_LOG"
