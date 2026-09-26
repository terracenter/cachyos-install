#!/bin/bash
# Instalador de Aplicaciones para Hyprland (CachyOS)
# Estructura modular inspirada en Omarchy

set -e

export CACHY_INSTALL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CACHY_LOG="/var/log/cachyos-hyprland-apps.log"

run_logged() {
  local script_path="$1"
  if [[ ! -f "$script_path" ]]; then
    echo "ERROR: Módulo de app no encontrado: $script_path" | tee -a "$CACHY_LOG"
    exit 1
  fi
  echo "==> Instalando paquete de apps: $(basename "$script_path")" | tee -a "$CACHY_LOG"
  source "$script_path" 2>&1 | tee -a "$CACHY_LOG"
  if (( PIPESTATUS[0] != 0 )); then
    echo "ERROR: Falló la instalación del módulo $(basename "$script_path")" | tee -a "$CACHY_LOG"
    exit 1
  fi
}

echo "Iniciando instalación de aplicaciones secundarias..." | tee -a "$CACHY_LOG"

# 1. Herramientas Core y Desarrollo
run_logged "$CACHY_INSTALL/install/apps/terminal-neovim.sh"
run_logged "$CACHY_INSTALL/install/apps/shell-tools.sh"
run_logged "$CACHY_INSTALL/install/apps/dev-tools.sh"
run_logged "$CACHY_INSTALL/install/apps/ia.sh"

# 2. Navegadores y GUIs (con Google Chrome en vez de Chromium)
run_logged "$CACHY_INSTALL/install/apps/navegadores.sh"
run_logged "$CACHY_INSTALL/install/apps/guis.sh"

# 3. Gaming, VMs y Productividad
run_logged "$CACHY_INSTALL/install/apps/gaming.sh"
run_logged "$CACHY_INSTALL/install/apps/vms-pdfs.sh"

echo "Instalación de aplicaciones completada con éxito." | tee -a "$CACHY_LOG"
