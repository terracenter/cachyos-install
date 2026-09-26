#!/bin/bash
step "Instalando Aplicaciones GUI (Ofimática, Media, Impresoras)..."
sudo pacman -S --needed --noconfirm \
    libreoffice-fresh xournalpp pinta gnome-calculator \
    cups cups-browsed cups-filters cups-pdf system-config-printer \
    grim slurp satty gpu-screen-recorder obs-studio \
    mpv imv imagemagick ffmpegthumbnailer sushi cliamp \
    signal-desktop localsend \
    tesseract tesseract-data-eng \
    > /dev/null 2>&1 || warn "Falló guis pacman"

sudo systemctl enable cups.service 2>/dev/null || true

paru -S --needed --noconfirm obsidian typora dropbox megasync-bin > /dev/null 2>&1 || warn "Falló guis AUR"
ok "Aplicaciones de escritorio (Office, Media) instaladas"
