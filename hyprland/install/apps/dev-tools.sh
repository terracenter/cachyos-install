#!/bin/bash
step "Instalando Ecosistema de Desarrollo..."

# Paquetes en repos oficiales
sudo pacman -S --needed --noconfirm \
    github-cli rust llvm clang \
    dotnet-runtime-9.0 ruby \
    python-poetry-core python-terminaltexteffects python-gobject \
    mariadb-libs postgresql-libs libqalculate libyaml libsecret \
    docker docker-buildx docker-compose \
    > /dev/null 2>&1 || warn "Falló algo en dev-tools pacman"

# Activar docker
sudo systemctl enable docker.service 2>/dev/null || true

# Paquetes AUR (mise y lazydocker no están en repos oficiales)
paru -S --needed --noconfirm \
    visual-studio-code-bin \
    ufw-docker \
    mise \
    lazydocker \
    > /dev/null 2>&1 || warn "Falló dev-tools AUR"

ok "Ecosistema de Desarrollo (Docker, VSCode, Rust, mise) instalado"
