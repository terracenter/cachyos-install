#!/usr/bin/env bash

# Utilidades compartidas para los modulos de Hyprland.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

step()   { printf '\n%b▶  %s%b\n' "${BLUE}${BOLD}" "$1" "$NC"; }
info()   { printf '   %b→  %s%b\n' "$DIM" "$1" "$NC"; }
ok()     { printf '   %b✔  %s%b\n' "$GREEN" "$1" "$NC"; }
warn()   { printf '   %b⚠  %s%b\n' "$YELLOW" "$1" "$NC"; }
die()    { printf '\n   %bERROR  %s%b\n\n' "$RED" "$1" "$NC" >&2; exit 1; }

header() {
    printf '\n%b┌────────────────────────────────────────────────────────────────────────────┐%b\n' "$CYAN" "$NC"
    printf '%b│ %-74s │%b\n' "$CYAN" "$1" "$NC"
    printf '%b└────────────────────────────────────────────────────────────────────────────┘%b\n' "$CYAN" "$NC"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Comando requerido no encontrado: $1"
}

project_root() {
    git -C "${SCRIPT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "${PROJECT_ROOT:-$PWD}"
}

show_script_version() {
    local script_name="${1:-script}"
    local script_path="${2:-}"
    local root version commit branch changed_date state

    root="$(project_root)"
    version="$(git -C "$root" describe --tags --always --dirty 2>/dev/null || printf 'sin-version')"
    commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || printf 'sin-git')"
    branch="$(git -C "$root" branch --show-current 2>/dev/null || printf 'desconocida')"
    changed_date="$(git -C "$root" log -1 --format='%cs' -- "$script_path" 2>/dev/null || true)"
    [[ -n "$changed_date" ]] || changed_date="sin-commit"
    state="limpio"
    [[ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ]] && state="con cambios locales"

    printf '%b%s%b\n' "${BOLD}${CYAN}" "$script_name" "$NC"
    printf 'Version: %s | Commit: %s | Rama: %s\n' "$version" "$commit" "$branch"
    printf 'Ultima modificacion: %s | Estado: %s\n\n' "$changed_date" "$state"
}
