#!/bin/bash
# Monitoreo de Actualizaciones: Omarchy Upstream
# Este script verifica si hay commits nuevos en la rama quattro de Omarchy.

set -e

UPSTREAM_URL="https://github.com/omacom/omarchy.git"
UPSTREAM_BRANCH="quattro"
CLONE_DIR="$(pwd)/.omarchy-upstream"

echo "==> Verificando actualizaciones en Omarchy ($UPSTREAM_BRANCH)..."

# Si no existe el clon bare, lo creamos
if [[ ! -d "$CLONE_DIR" ]]; then
  echo "    Clonando repositorio upstream (bare) por primera vez..."
  git clone --bare -b "$UPSTREAM_BRANCH" "$UPSTREAM_URL" "$CLONE_DIR" >/dev/null 2>&1
  echo "    Clon inicial completado. (Puedes ver el log entrando a $CLONE_DIR y usando git log)"
  exit 0
fi

# Hacer fetch para buscar novedades
echo "    Buscando nuevos commits..."
git -C "$CLONE_DIR" fetch origin "$UPSTREAM_BRANCH":"$UPSTREAM_BRANCH" -q

# Comparar (como es bare, vemos los últimos commits)
echo ""
echo "Últimos 5 commits en upstream:"
echo "--------------------------------------------------"
git -C "$CLONE_DIR" log -n 5 --oneline --color=always
echo "--------------------------------------------------"
echo "Para ver detalles de un commit específico: git -C $CLONE_DIR show <hash>"

