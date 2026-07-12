← [Cap. 16 — Acceso remoto](Capítulo-16-Acceso-Remoto.md) · [Índice](..) · [Cap. 18 — Gaming](Capítulo-18-Gaming.md) →

---

## Introducción

Este capítulo cubre las herramientas de línea de comandos modernas que forman parte del stack de Omarchy. Están todas disponibles en los repositorios oficiales de CachyOS/Arch — no se requiere AUR.

La mayoría ya fue instalada por `install-cachyos-hyprland.sh`. Las secciones de configuración aplican sobre una instalación existente; cada herramienta verifica si está instalada antes de proceder.

> **Prerequisito:** Haber completado el Capítulo 12 (instalación del entorno gráfico).

> `tmux` no se instala aquí. Es una herramienta para sesiones SSH remotas — instálala con `paru -S tmux` en los servidores donde la necesites.

---

## Checklist de la fase

- [ ] eza instalado y alias configurados
- [ ] bat instalado y alias configurados
- [ ] ripgrep instalado y validado
- [ ] fzf instalado con integración de shell
- [ ] zoxide instalado con integración de shell
- [ ] dust instalado y validado
- [ ] btop instalado y validado
- [ ] fastfetch instalado y validado
- [ ] starship instalado y configurado como prompt
- [ ] Aliases persistidos en `~/.zshrc`
- [ ] Cambios validados en sesión nueva
- [ ] Commit de checkpoint creado

---

## 1. Instalación

Todas estas herramientas están en los repositorios oficiales. El script de instalación ya las incluye en `PKGS_CLI` y `PKGS_TERMINAL`. Para verificar si están instaladas o instalar manualmente:

```bash
paru -S --needed \
    eza bat ripgrep fzf zoxide dust \
    btop fastfetch starship
```

Verificar que todas estén presentes:

```bash
for cmd in eza bat rg fzf zoxide dust btop fastfetch starship; do
    command -v "$cmd" &>/dev/null && echo "✓ $cmd" || echo "✗ $cmd FALTA"
done
```

Salida esperada:

```
✓ eza
✓ bat
✓ rg
✓ fzf
✓ zoxide
✓ dust
✓ btop
✓ fastfetch
✓ starship
```

---

## 2. Configuración del shell

Agregar al final de `~/.zshrc`:

```bash
vim ~/.zshrc
```

Contenido a añadir al final del archivo:

```zsh
# ─── Herramientas CLI modernas ────────────────────────────────────────────────

# eza — listado moderno
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -l --git'
alias la='eza --icons --group-directories-first -la --git'
alias lt='eza --icons --tree --level=2'

# bat — visor con sintaxis
alias cat='bat --paging=never'
alias less='bat --paging=always'

# dust — uso de disco
alias du='dust'

# zoxide — cd inteligente
eval "$(zoxide init zsh)"

# fzf — integración de shell
[[ -f /usr/share/fzf/key-bindings.zsh ]] && source /usr/share/fzf/key-bindings.zsh
[[ -f /usr/share/fzf/completion.zsh   ]] && source /usr/share/fzf/completion.zsh

# starship — prompt
eval "$(starship init zsh)"

# Fix TERM para sesiones SSH sin terminfo del emulador local
if [[ -n "$SSH_CONNECTION" ]] && ! infocmp "$TERM" &>/dev/null; then
  export TERM=xterm-256color
fi

# Fix backspace/delete para terminales modernas (Alacritty)
bindkey "^?" backward-delete-char
bindkey "^H" backward-delete-char
bindkey "^[[3~" delete-char
```

Aplicar sin reiniciar sesión:

```bash
source ~/.zshrc
```

---

## 2.1 Fixes para terminal remota (SSH desde Alacritty)

Alacritty envía `TERM=alacritty` al conectarse por SSH. Si el servidor remoto no tiene el terminfo de Alacritty instalado, el backspace, delete y los colores dejan de funcionar. Estos dos fixes se agregan al final de `~/.zshrc` y viajan con rsync a todos los remotos.

### Fix 1 — TERM fallback

```zsh
# Fix TERM para sesiones SSH sin terminfo del emulador local
if [[ -n "$SSH_CONNECTION" ]] && ! infocmp "$TERM" &>/dev/null; then
  export TERM=xterm-256color
fi
```

Detecta si estamos en una sesión SSH y si el terminfo del `TERM` actual no existe en el servidor. Si falta, cae a `xterm-256color` que todos los servidores conocen. No afecta la sesión local.

### Fix 2 — Backspace y delete en zsh

```zsh
# Fix backspace/delete para terminales modernas (Alacritty)
bindkey "^?" backward-delete-char
bindkey "^H" backward-delete-char
bindkey "^[[3~" delete-char
```

Mapea explícitamente las teclas backspace (`^?` y `^H`) y delete (`^[[3~`) en ZLE (Zsh Line Editor). Algunos servidores remotos tienen configuraciones de `stty erase` que no coinciden con lo que envía Alacritty.

### Validación

Conectarse a un servidor remoto por SSH y verificar:

```bash
# Verificar que TERM es compatible
echo $TERM
# Esperado en remoto sin terminfo alacritty: xterm-256color

# Verificar backspace (escribir algo y borrar con backspace)
# Verificar delete (escribir algo, mover cursor atrás, presionar Delete)
```

---

## 3. eza — listado de archivos moderno

Reemplaza `ls`. Muestra iconos Nerd Font, colores, permisos y estado git en una sola vista.

### Validación

```bash
ls /etc | head -10
```

Salida esperada: listado con íconos de archivo/directorio y colores por tipo.

```bash
ll ~/.config
```

Salida esperada: permisos, tamaño, fecha y estado git (si aplica) con iconos.

---

## 4. bat — visor de archivos con resaltado

Reemplaza `cat`. Añade resaltado de sintaxis, numeración de líneas y paginación automática.

### Validación

```bash
cat ~/.zshrc
```

Salida esperada: contenido con resaltado de sintaxis bash y numeración de líneas.

```bash
cat /etc/pacman.conf | head -20
```

Salida esperada: resaltado de sintaxis INI.

### Config opcional

```bash
mkdir -p ~/.config/bat
cat > ~/.config/bat/config <<'EOF'
--theme="Catppuccin-mocha"
--style="numbers,changes,header"
EOF
```

Verificar tema disponible:

```bash
bat --list-themes | grep -i catppuccin
```

Si no aparece Catppuccin, instalar el tema:

```bash
mkdir -p "$(bat --config-dir)/themes"
curl -Lo "$(bat --config-dir)/themes/Catppuccin-mocha.tmTheme" \
    "https://raw.githubusercontent.com/catppuccin/bat/main/themes/Catppuccin%20Mocha.tmTheme"
bat cache --build
```

---

## 5. ripgrep — búsqueda de texto ultrarrápida

Reemplaza `grep`. Respeta `.gitignore`, busca recursivamente por defecto y es significativamente más rápido.

### Validación

```bash
rg "hypridle" ~/.config/hypr/
```

Salida esperada: líneas que contienen `hypridle` con nombre de archivo y número de línea.

```bash
rg -l "waybar" ~/.config/
```

Salida esperada: lista de archivos que contienen la palabra `waybar`.

---

## 6. fzf — buscador difuso interactivo

Herramienta de filtrado interactivo. Con la integración de shell habilitada:

| Combinación | Acción |
|---|---|
| `Ctrl + R` | Historial de comandos con búsqueda difusa |
| `Ctrl + T` | Seleccionar archivo del directorio actual |
| `Alt + C` | Navegar a subdirectorio |

### Validación

Presionar `Ctrl+R` en la terminal: debe abrirse un selector interactivo del historial de comandos.

```bash
vim $(fzf)
```

Debe abrir un selector de archivos del directorio actual.

---

## 7. zoxide — navegación inteligente de directorios

Reemplaza `cd`. Aprende los directorios más frecuentados y permite saltar a ellos con fragmentos del nombre.

### Validación

Navegar a algunos directorios para que zoxide aprenda:

```bash
cd ~/.config/hypr && cd ~/.config/waybar && cd ~
```

Luego saltar directamente:

```bash
z hypr
```

Salida esperada: cambio de directorio a `~/.config/hypr` sin escribir la ruta completa.

```bash
zi
```

Abre un selector fzf con los directorios más frecuentados.

---

## 8. dust — analizador de uso de disco

Reemplaza `du`. Muestra el uso de disco con barras proporcionales visuales.

### Validación

```bash
dust ~/.config
```

Salida esperada: árbol de directorios con barras de uso proporcional, ordenado de mayor a menor.

```bash
dust -d 1 /
```

Salida esperada: uso de disco del raíz con profundidad 1.

---

## 9. btop — monitor de recursos del sistema

Reemplaza `htop`. Interfaz TUI con gráficas de CPU, memoria, disco y red. El ícono de CPU en waybar lanza `btop` al hacer clic.

### Validación

```bash
btop
```

Salida esperada: interfaz TUI completa con gráficas de recursos. Salir con `q`.

También accesible desde waybar haciendo clic en el ícono de CPU.

---

## 10. fastfetch — información del sistema

Reemplaza `neofetch`. Más rápido y con más opciones de configuración.

### Validación

```bash
fastfetch
```

Salida esperada: logo de la distribución con información del sistema (OS, kernel, DE, terminal, CPU, GPU, memoria, disco).

### Config básica

```bash
fastfetch --gen-config
```

El archivo de configuración se crea en `~/.config/fastfetch/config.jsonc`.

---

## 11. starship — prompt de shell personalizable

Muestra información contextual en el prompt: directorio, rama git, estado del repositorio, entorno virtual Python, versión de Node/Rust, etc.

### Validación

Abrir una terminal nueva o ejecutar `source ~/.zshrc`. El prompt debe cambiar de aspecto.

En un directorio con git:

```bash
cd ~/.config/hypr
```

El prompt debe mostrar el nombre de la rama y el estado del repositorio.

### Config básica (opcional)

Crear `~/.config/starship.toml`:

```toml
format = """
$directory$git_branch$git_status$character"""

[directory]
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = " "
style = "bold purple"

[git_status]
style = "bold red"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
```

---

## Validación final

Ejecutar en una terminal nueva (para verificar que los cambios persisten tras `source ~/.zshrc`):

```bash
# Verificar aliases activos
type ls && type cat && type du

# Verificar prompt starship
echo $STARSHIP_SESSION_KEY

# Verificar zoxide activo
type z

# Verificar fzf integrado
bindkey | grep fzf
```

Salida esperada: todos los comandos resuelven correctamente sin errores.

---

## Checkpoint — commit de la fase

Una vez validadas todas las herramientas en el laptop:

```bash
git add Capítulo-17-Herramientas-CLI-modernas.md install-cachyos-hyprland.sh
git commit -m "feat: Fase 1 completada — herramientas CLI modernas del stack Omarchy"
```

---

← [Cap. 16 — Acceso remoto](Capítulo-16-Acceso-Remoto.md) · [Índice](..) · [Cap. 18 — Gaming](Capítulo-18-Gaming.md) →
