#!/bin/bash
step "Instalando Navegadores..."
paru -S --needed --noconfirm google-chrome zen-browser-bin > /dev/null 2>&1 || warn "Falló navegadores"
ok "Google Chrome y Zen Browser instalados"
