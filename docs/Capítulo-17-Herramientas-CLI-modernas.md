# Capítulo 17: Herramientas CLI modernas

[← Cap. 16: Acceso remoto](Capítulo-16-Acceso-Remoto.md) · [Índice](./_index.md) · [Cap. 18: Gaming →](Capítulo-18-Gaming.md)

## Alcance

Las herramientas modernas complementan las utilidades tradicionales de Unix. No deben sustituir globalmente comandos esenciales dentro de scripts del sistema.

La instalación de estas herramientas corresponde a los módulos opcionales de aplicaciones, especialmente:

```text
hyprland/install/apps/shell-tools.sh
hyprland/install/apps/terminal-neovim.sh
```

Comprueba los scripts antes de afirmar que una utilidad se instala automáticamente.

## Herramientas recomendadas

| Uso | Tradicional | Alternativa |
|---|---|---|
| Listar archivos | `ls` | `eza` |
| Ver archivos | `cat` | `bat` |
| Buscar texto | `grep` | `ripgrep` (`rg`) |
| Buscar archivos | `find` | `fd` |
| Uso de disco | `du` | `dust` |
| Monitor del sistema | `top` | `btop` |
| Buscar interactivamente | varias | `fzf` |
| Navegar directorios | `cd` | `zoxide` |
| Prompt | shell | `starship` |

Instala únicamente las herramientas disponibles en los repositorios configurados:

```bash
sudo pacman -S --needed eza bat ripgrep fd fzf zoxide btop
```

Comprueba Starship antes de instalar:

```bash
pacman -Si starship
```

## Alias seguros

Evita reemplazos globales como:

```text
alias cat=bat
alias du=dust
```

Pueden cambiar opciones, formato y comportamiento esperado. Prefiere alias explícitos:

```bash
alias ll='eza -la --group-directories-first'
alias preview='bat --paging=always'
alias disks='dust'
```

Los scripts deben seguir usando las herramientas estándar cuando su compatibilidad sea importante.

## fzf

`fzf` es un selector difuso de propósito general. En Bash reciente puede activarse con:

```bash
eval "$(fzf --bash)"
```

En Zsh:

```bash
source <(fzf --zsh)
```

Atajos comunes:

```text
Ctrl+R   buscar historial
Ctrl+T   seleccionar archivos
Alt+C    cambiar de directorio
```

Añade la inicialización una sola vez y solo al archivo de la shell utilizada.

## zoxide

Inicializa zoxide en Bash:

```bash
eval "$(zoxide init bash)"
```

En Zsh:

```bash
eval "$(zoxide init zsh)"
```

Ejemplo:

```bash
z cachyos
```

## Starship

En Bash:

```bash
eval "$(starship init bash)"
```

En Zsh:

```bash
eval "$(starship init zsh)"
```

No descargues configuraciones remotas directamente sobre tus archivos sin revisarlas. Conserva tu configuración en:

```text
~/.config/starship.toml
```

## SSH y shell remota

Una shell remota puede no tener Nerd Fonts, colores o utilidades opcionales. Mantén las configuraciones condicionales:

```bash
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
```

```bash
command -v starship >/dev/null && eval "$(starship init bash)"
```

No dupliques bloques de inicialización en `.bashrc`, `.zshrc` y archivos de perfil sin comprender cuándo se carga cada uno.

## Validación

```bash
command -v eza bat rg fd fzf zoxide btop
```

```bash
shellcheck ~/.bashrc 2>/dev/null || true
```

Para Zsh, inicia una shell nueva y revisa mensajes de error:

```bash
zsh -i -c exit
```

## Buenas prácticas

- Instala desde Pacman cuando el paquete esté en repositorios configurados.
- Usa AUR solo después de revisar `PKGBUILD` y archivos relacionados.
- Prefiere alias nuevos en lugar de reemplazar comandos básicos.
- Aplica configuraciones por shell.
- Mantén funcionales las sesiones SSH sin temas ni fuentes especiales.
- Documenta únicamente integraciones realmente presentes en Waybar o Hyprland.

## Referencias

- Utilidades principales: <https://wiki.archlinux.org/title/Core_utilities>
- fzf: <https://wiki.archlinux.org/title/Fzf>
- Starship: <https://starship.rs/>
- zoxide: <https://github.com/ajeetdsouza/zoxide>
