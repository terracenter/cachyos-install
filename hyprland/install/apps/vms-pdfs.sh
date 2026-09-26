#!/bin/bash
step "Instalando Virtualización y PDFs..."
sudo pacman -S --needed --noconfirm qemu-full virt-manager swtpm evince > /dev/null 2>&1 || warn "Falló vms-pdfs"
sudo systemctl enable libvirtd.socket 2>/dev/null || true
ok "QEMU y Evince instalados"
