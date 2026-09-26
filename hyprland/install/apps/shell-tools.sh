#!/bin/bash
step "Instalando Herramientas CLI modernas..."
sudo pacman -S --needed --noconfirm \
    ripgrep fd bat eza dust jq gum xmlstarlet usage \
    bluetui bolt impala wiremix socat \
    btop fastfetch inxi \
    > /dev/null 2>&1 || warn "Falló algo en shell-tools"
ok "Herramientas CLI modernas instaladas"
