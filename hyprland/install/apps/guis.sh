#!/bin/bash
step "Instalando Aplicaciones GUI (Ofimática, Media, Impresoras)..."

# Usar paru para TODO, asegurando que tanto paquetes oficiales como AUR se instalen
paru -S --needed --noconfirm \
    libreoffice-fresh xournalpp pinta gnome-calculator \
    cups cups-browsed cups-filters cups-pdf system-config-printer \
    grim slurp satty gpu-screen-recorder obs-studio \
    mpv imv imagemagick ffmpegthumbnailer sushi cliamp \
    signal-desktop localsend \
    tesseract tesseract-data-eng \
    obsidian typora dropbox megasync-bin \
    > /dev/null 2>&1 || warn "Falló la instalación de guis con paru"

sudo systemctl enable cups.service 2>/dev/null || true

ok "Aplicaciones de escritorio (Office, Media) instaladas"
