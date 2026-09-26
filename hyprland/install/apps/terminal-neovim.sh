#!/bin/bash
step "Instalando Terminal y Entorno Neovim..."
sudo pacman -S --needed --noconfirm \
    alacritty starship zoxide fzf zsh zsh-completions \
    zsh-syntax-highlighting zsh-autosuggestions \
    neovim lazygit tree-sitter-cli luarocks \
    > /dev/null 2>&1 || warn "Falló algo en terminal-neovim"
ok "Alacritty, Zsh y Neovim instalados"
