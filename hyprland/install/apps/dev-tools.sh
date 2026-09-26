#!/bin/bash
step "Instalando Ecosistema de Desarrollo..."

# Usar paru para TODO, asegurando que tanto paquetes oficiales como AUR se instalen
paru -S --needed --noconfirm \
    github-cli rust llvm clang \
    dotnet-runtime-9.0 ruby \
    python-poetry-core python-terminaltexteffects python-gobject \
    mariadb-libs postgresql-libs libqalculate libyaml libsecret \
    docker docker-buildx docker-compose \
    visual-studio-code-bin \
    ufw-docker \
    mise \
    lazydocker \
    > /dev/null 2>&1 || warn "Falló algo en dev-tools paru"

# Activar docker
sudo systemctl enable docker.service 2>/dev/null || true

ok "Ecosistema de Desarrollo instalado"
