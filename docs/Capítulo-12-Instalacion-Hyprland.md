← [Cap. 11 — Rollback](Capítulo-11-Rollback.md) · [Índice](..) · [Cap. 13 — Configuración Waybar](Capítulo-13-Configuracion-Waybar.md) →

---

## Procedimiento de instalación

Este capítulo cubre la instalación completa del entorno gráfico: primero el script base (`install-cachyos-hyprland.sh`) que instala Hyprland, SDDM y servicios esenciales, y luego el script de personalización (`install-hyprland-desktop.sh`) que configura el escritorio al estilo Omarchy. Requiere CachyOS instalado con BTRFS y snapper configurado (Capítulos 5 y 6).

### Requisitos previos

- CachyOS instalado y funcional
- `install-cachyos-hyprland.sh` ejecutado y sistema reiniciado
- Acceso SSH al equipo (o terminal directa)
- Los scripts disponibles en el equipo (transferir vía `scp` si es necesario)

### Por qué los scripts se copian a /root/ y se ejecutan via su

Los scripts usan `paru` (gestor AUR) que **rechaza ejecutarse como root**. Sin embargo, en una instalación fresca el usuario normal todavía no tiene SSH configurado. La solución: copiar los scripts a `/root/`, conectar como root, y cambiar al usuario con `su -` antes de ejecutar.

Una vez que el sistema está instalado y el usuario tiene clave SSH configurada, no es necesario pasar por root — los scripts de post-instalación opcionales (como `install-gaming.sh`) se copian directamente al home del usuario.

### Transferir los scripts de instalación (sistema fresco)

Desde tu workstation, copiar los scripts al equipo destino vía root (el usuario normal aún no tiene SSH configurado):

```bash
scp scripts/install-cachyos-hyprland.sh scripts/install-hyprland-desktop.sh \
    scripts/install-completo.sh root@IP_DEL_EQUIPO:/root/
```

### Opción A — Instalación en un solo paso (recomendada)

`install-completo.sh` es un wrapper que encadena automáticamente los dos scripts de post-instalación. Evita tener que reconectar y relanzar manualmente la segunda fase.

```bash
ssh root@IP_DEL_EQUIPO
su - USUARIO
bash /root/install-completo.sh
```

Internamente ejecuta en secuencia:
1. `install-cachyos-hyprland.sh` — paquetes, servicios, SDDM, GRUB theme switcher, SDDM bg switcher
2. `install-hyprland-desktop.sh` (con `SKIP_SYSTEM_UPDATE=1`) — escritorio, dotfiles, temas, Waybar

La segunda fase omite la actualización de mirrors y `pacman -Syu` porque ya corrieron en la primera. Al finalizar, reiniciar:

```bash
sudo reboot
```

### Opción B — Instalación por pasos (diagnóstico o personalización)

Útil cuando se quiere revisar el estado entre fases o instalar solo una de ellas.

**Paso 1 — Script base:**

```bash
ssh root@IP_DEL_EQUIPO
su - USUARIO
bash /root/install-cachyos-hyprland.sh
```

El script presenta un menú interactivo para seleccionar componentes opcionales (dev tools, QEMU, navegadores, etc.). Al finalizar, reiniciar el equipo.

**Paso 2 — Script de escritorio:**

Después del reinicio, el equipo arranca en SDDM. Conectar por SSH de nuevo:

```bash
ssh root@IP_DEL_EQUIPO
su - USUARIO
bash /root/install-hyprland-desktop.sh
```

Este script instala y configura: waybar, rofi, mako, kitty, alacritty, temas Catppuccin Mocha, sistema de temas Omarchy, capturas, grabación, audio, bluetooth, firewall, DNS local, impresión y demás componentes documentados en este capítulo. Detecta automáticamente si el equipo es laptop o desktop y omite componentes que no aplican (TLP, touchpad).

### Si el script aborta sin mostrar el banner de éxito

Cada script imprime la línea exacta y el comando que fallaron, y deja el detalle en el log junto al propio script:

```
install-cachyos-hyprland.log
install-hyprland-desktop.log
```

Si se usó `install-completo.sh`, el log correspondiente a la fase que falló es el que contiene el error.

### Si el script aborta sin mostrar el banner de éxito

Cada script imprime la línea exacta y el comando que fallaron, y deja el detalle en el log junto al propio script:

```
install-cachyos-hyprland.log
install-hyprland-desktop.log
```

Si se usó `install-completo.sh`, el log correspondiente a la fase que falló es el que contiene el error.

### Primer login en Hyprland

Al terminar (opción A o B), iniciar sesión en SDDM. Es el primer login real en Hyprland — en este momento se activan los servicios de usuario (PipeWire, autostart de apps), el keyring se desbloquea automáticamente y el tema por defecto (nord) se aplica.

---

## Créditos

Este script está inspirado en el trabajo de **DHH** (David Heinemeier Hansson), creador de Ruby on Rails y Basecamp, quien publicó [Omarchy](https://github.com/basecamp/omarchy) — una configuración opinionada de Hyprland para Arch Linux.

El trabajo de portabilidad a CachyOS fue realizado por **mroboff** en el repositorio [omarchy-on-cachyos](https://github.com/mroboff/omarchy-on-cachyos), que identifica y resuelve los conflictos entre Omarchy y CachyOS: bootloader, drivers NVIDIA, backend WiFi, y hooks de pacman.

Nuestro script toma la misma filosofía de control y verificación, adaptada a CachyOS Hyprland nativo con detección automática de GPU y una selección de paquetes orientada a producción.

---

## Referencia: paquetes del script original de Omarchy

La siguiente tabla lista todos los paquetes del archivo `omarchy-base.packages` del repositorio oficial de Omarchy. Sirve como referencia para decisiones de inclusión en nuestro script.

### Hyprland y Wayland

| Paquete | Descripción |
|---|---|
| `hyprland` | Compositor Wayland con tiling dinámico — reemplaza el servidor X11, gestiona ventanas, workspaces y efectos visuales |
| `hypridle` | Daemon de inactividad — ejecuta acciones tras N minutos sin actividad (apagar pantalla, bloquear, suspender) |
| `hyprlock` | Bloqueo de pantalla nativo de Hyprland — se activa con `Super+Ctrl+L` o automáticamente via hypridle |
| `hyprpicker` | Selector de color — hace clic en cualquier punto de la pantalla y devuelve el código HEX/RGB del color |
| `hyprsunset` | Filtro de luz azul — reduce la temperatura de color en la noche para proteger la vista |
| `hyprland-guiutils` | Utilidades GUI para Hyprland (hyprpm, etc.) |
| `hyprland-preview-share-picker` | Selector de ventana/pantalla para compartir en videoconferencias vía el portal XDG |
| `uwsm` | Universal Wayland Session Manager — gestiona el ciclo de vida de la sesión Wayland con integración systemd |
| `xdg-desktop-portal-hyprland` | Portal XDG para Hyprland — habilita captura de pantalla, grabación y selector de ventanas para apps como OBS y videoconferencias. Sin él, compartir pantalla no funciona. |
| `xdg-desktop-portal-gtk` | Portal XDG fallback para apps GTK — proporciona el diálogo nativo de "Abrir archivo" en navegadores y apps Electron |
| `xdg-terminal-exec` | Define qué terminal abrir cuando una app solicita una terminal genérica |
| `qt5-wayland` | Permite que las apps Qt5 corran nativamente en Wayland sin necesitar XWayland |
| `wireplumber` | Gestor de sesiones PipeWire — controla el routing de audio y vídeo entre dispositivos y apps |
| `wl-clipboard` | Portapapeles Wayland — provee `wl-copy` y `wl-paste`, necesarios para cliphist y otros scripts |

### Barra, notificaciones y fondo

| Paquete | Descripción |
|---|---|
| `waybar` | Barra de estado — muestra workspaces, hora, volumen, red y otros módulos. Configurable en JSON con temas CSS |
| `mako` | Daemon de notificaciones para Wayland — muestra las notificaciones del sistema en esquina de pantalla |
| `swayosd` | OSD (On-Screen Display) — muestra indicador visual al subir/bajar volumen o brillo |
| `swaybg` | Daemon de fondo de pantalla para Wayland — aplica y mantiene el wallpaper activo |
| `quickshell` | Shell de escritorio declarativo para Wayland (alternativa a waybar, no instalado en este script) |

### Display manager y sesión

| Paquete | Descripción |
|---|---|
| `sddm` | Display manager gráfico — pantalla de login con soporte Wayland nativo y temas |
| `plymouth` | Splash screen animado durante el arranque — oculta los mensajes del kernel con una pantalla gráfica |
| `polkit-gnome` | Agente gráfico de PolicyKit — ver sección Autenticación para descripción completa |

### Lanzadores

| Paquete | Descripción |
|---|---|
| `rofi` | Lanzador de aplicaciones con tema Catppuccin Mocha — abre apps, cambia temas, muestra portapapeles y keybindings (`Super+Space`) |
| `cliphist` | Historial de portapapeles para Wayland — guarda todo lo copiado y permite recuperarlo desde rofi (`Super+Ctrl+V`) |
| `wl-clipboard` | Herramientas de portapapeles Wayland: `wl-copy` (copiar) y `wl-paste` (pegar) — necesarias para cliphist y scripts |
| `omarchy-walker` | ~~Lanzador Walker — versión del repo Omarchy~~ **Excluido** |

### Terminal y shell

| Paquete | Descripción |
|---|---|
<<<<<<< HEAD
| `kitty` | Emulador de terminal GPU-accelerated, nativo Wayland — terminal por defecto (`Super+Enter`). JetBrains Mono 16, Material Dark, copy-on-select, Ctrl+clic en URLs |
| `alacritty` | Emulador de terminal alternativo — se instala pero Kitty es el default |
=======
| `alacritty` | Emulador de terminal GPU-accelerated, nativo Wayland — terminal por defecto (`Super+Q`). Configurado con JetBrains Mono, Catppuccin Mocha y padding |
>>>>>>> origin/main
| `tmux` | Multiplexor de terminal — divide la terminal en paneles y mantiene sesiones vivas al desconectarse. Útil en SSH, no se usa en el escritorio local donde Hyprland gestiona el tiling |
| `zsh` | Shell interactivo con sintaxis avanzada — shell por defecto del usuario |
| `zsh-syntax-highlighting` | Resaltado de sintaxis en tiempo real en el prompt de zsh |
| `zsh-autosuggestions` | Sugerencias de comandos basadas en historial — acepta con la flecha derecha |
| `starship` | Prompt de shell personalizable — muestra rama git, versión de runtime, estado del último comando, etc. |
| `zoxide` | Navegador de directorios con memoria — `z nombre` salta al directorio más visitado que coincida, sin escribir la ruta completa |
| `fzf` | Buscador difuso interactivo — filtra listas en tiempo real; integrado en zsh para historial y `Ctrl+R` |
| `bash-completion` | Autocompletado extendido para bash — completa subcomandos, flags y argumentos con Tab |

> **Oh My Zsh** se instala durante la fase `install-base.sh` (dentro del chroot, como usuario normal). El `.zshrc` generado usa el tema `bira` con los plugins: `git`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `docker-compose`, `gcloud`, `python`. Los plugins del sistema (`/usr/share/zsh/plugins/`) se enlazan con symlinks a `~/.oh-my-zsh/custom/plugins/`.

### Herramientas de sistema

| Paquete | Descripción |
|---|---|
| `btop` | Monitor de recursos del sistema — CPU, RAM, disco, red y procesos en tiempo real con interfaz TUI |
| `fastfetch` | Muestra información del sistema (distro, kernel, RAM, GPU) en terminal — similar a neofetch pero más rápido |
| `inxi` | Información detallada de hardware desde CLI — útil para diagnóstico y reportes de soporte |
| `kernel-modules-hook` | Regenera los módulos del kernel automáticamente al actualizarlo — evita errores de módulo no encontrado tras updates |
| `iwd` | ~~Backend WiFi Intel~~ **Excluido — se mantiene NetworkManager** |
| `power-profiles-daemon` | Gestión de perfiles de energía (ahorro, balanceado, rendimiento) — controlado por GNOME y otros escritorios |
| `brightnessctl` | Control de brillo de pantalla desde CLI — usado por swayosd para los keybindings de brillo |
| `pamixer` | Control de volumen PulseAudio/PipeWire desde CLI |
| `playerctl` | Controla reproductores multimedia (Spotify, mpv, browsers) desde CLI o keybindings |
| `man-db` | Base de datos y visor de páginas del manual (`man comando`) |
| `less` | Paginador de texto — permite desplazarse por salidas largas en terminal |
| `unzip` | Descompresor de archivos ZIP |
| `plocate` | Búsqueda rápida de archivos por nombre usando índice — alternativa moderna a `locate` |
| `expac` | Consulta información de paquetes pacman en formato personalizable |
| `whois` | Consulta registros WHOIS de dominios e IPs |
| `inetutils` | Utilidades de red básicas: `ping`, `traceroute`, `hostname`, `ftp` |
| `tzupdate` | Detecta y actualiza la zona horaria automáticamente según la ubicación |
| `wireless-regdb` | Base de datos de regulaciones WiFi por país — necesaria para usar canales WiFi correctamente |
| `alsa-utils` | Utilidades ALSA: `alsamixer`, `aplay`, `arecord` — necesarias aunque se use PipeWire |
| `avahi` | Daemon mDNS/DNS-SD — permite descubrir servicios en la red local (impresoras, NAS, etc.) |
| `nss-mdns` | Resolución de nombres `.local` via mDNS — permite hacer `ping hostname.local` en la red |

### Archivos y almacenamiento

| Paquete | Descripción |
|---|---|
| `udiskie` | Automontaje de discos USB y externos — monta dispositivos automáticamente al conectarlos y añade ícono en la bandeja del sistema para expulsarlos de forma segura |
| `nautilus` | Gestor de archivos gráfico — soporta `admin://` para editar archivos con privilegios via polkit |
| `nautilus-python` | Permite extensiones Python en Nautilus (menús contextuales personalizados, etc.) |
| `gnome-disk-utility` | Gestor de discos gráfico — formatea, particiona y verifica discos con interfaz visual |
| `dosfstools` | Herramientas para crear y reparar sistemas de archivos FAT/FAT32 (USB, tarjetas SD) |
| `exfatprogs` | Herramientas para sistemas de archivos exFAT — necesario para USB y tarjetas SD de gran capacidad |
| `gvfs-mtp` | Permite montar dispositivos Android en Nautilus via MTP (transferencia de archivos) |
| `gvfs-nfs` | Permite montar recursos compartidos NFS desde Nautilus |
| `gvfs-smb` | Permite montar recursos compartidos SMB/Samba (Windows/NAS) desde Nautilus |

> [!NOTE] Nautilus vs Thunar (Gestión de Archivos e Integración con Google Drive)
> El instalador ofrece elegir entre **Nautilus** (default en Hyprland) y **Thunar** (default en Qtile). La elección impacta directamente en el soporte para almacenamiento en la nube:
> *   **Nautilus (GNOME):** Cuenta con integración nativa plug-and-play con Google Drive y OneDrive. Al iniciar sesión en tus cuentas de red en GNOME (vía `gnome-online-accounts` + `gvfs-google`), tu unidad de Google Drive se monta automáticamente en el panel lateral de Nautilus sin configuraciones manuales. Es un gestor más moderno y visual, pero más pesado y con mayor consumo de recursos.
> *   **Thunar (XFCE):** Es extremadamente ligero, rápido e ideal para entornos minimalistas como Qtile. Sin embargo, **no cuenta con integración nativa para Google Drive**. Para acceder a tus unidades en la nube desde Thunar, deberás realizar una configuración manual utilizando herramientas de consola de terceros como **`rclone`** (`rclone mount`) o `google-drive-ocamlfuse`.

### Fuentes tipográficas

| Paquete | Descripción |
|---|---|
| `noto-fonts` | Fuentes Noto con cobertura amplia |
| `noto-fonts-cjk` | Fuentes para chino, japonés y coreano |
| `noto-fonts-emoji` | Fuentes para emojis |
| `ttf-ia-writer` | Fuente iA Writer para lectura |
| `ttf-jetbrains-mono-nerd` | JetBrains Mono con Nerd Fonts |
| `woff2-font-awesome` | Font Awesome en WOFF2 |

### Temas y apariencia

| Paquete | Descripción |
|---|---|
| `gnome-themes-extra` | Temas GNOME adicionales — incluye Adwaita y Adwaita-dark, usados como base para apps GTK en temas light |
| `kvantum-qt5` | Motor de temas SVG para Qt5 — permite aplicar temas Catppuccin a apps Qt (KDE-based) con el mismo aspecto que GTK |
| `yaru-icon-theme` | Tema de iconos Ubuntu Yaru — alternativa a Papirus |
| `fontconfig` | Sistema de configuración y renderizado de fuentes — controla antialiasing, hinting y sustitución de fuentes |

### Captura y grabación

| Paquete | Descripción |
|---|---|
| `grim` | Captura de pantalla para Wayland — toma la captura de área, ventana o pantalla completa |
| `slurp` | Selección interactiva de área en pantalla — se usa junto a grim para capturas de región |
| `satty` | Anotador de capturas — abre la imagen capturada para añadir flechas, texto y resaltados antes de guardar |
| `gpu-screen-recorder` | Grabador de pantalla con aceleración GPU — muy bajo impacto en rendimiento |
| `obs-studio` | Grabación y streaming profesional — usa xdg-desktop-portal-hyprland para capturar la pantalla |

### Multimedia

| Paquete | Descripción |
|---|---|
| `mpv` | Reproductor multimedia ligero y potente — soporta prácticamente cualquier formato, excelente para streams IPTV y vídeo local |
| `imv` | Visor de imágenes nativo Wayland — rápido, sin dependencias GNOME, ideal para uso desde terminal |
| `imagemagick` | Suite de procesamiento de imágenes desde CLI — convierte, redimensiona, combina y transforma imágenes en lote |
| `ffmpegthumbnailer` | Genera miniaturas de vídeo para Nautilus y otros gestores de archivos |
| `sushi` | Vista previa rápida de archivos en Nautilus con la barra espaciadora (imágenes, PDF, texto) |
| `cliamp` | Reproductor de audio desde CLI |
| `spotify` | Cliente oficial de Spotify (AUR) |

### Comunicación

| Paquete | Descripción |
|---|---|
| `signal-desktop` | Mensajería cifrada Signal |
| `localsend` | Transferencia de archivos en red local |

### Ofimática y documentos

| Paquete | Descripción |
|---|---|
| `libreoffice-fresh` | Suite ofimática completa — Writer, Calc, Impress, Draw (rama de actualización frecuente) |
| `evince` | Visor de PDF y documentos — ligero, con soporte de formularios y anotaciones |
| `obsidian` | Gestión de conocimiento en Markdown — base de notas local con links bidireccionales y plugins |
| `typora` | Editor Markdown WYSIWYG — edita y previsualiza Markdown en tiempo real sin modo dividido (AUR) |
| `drawio-desktop` | Editor de diagramas offline — flujos, arquitecturas, redes, UML; compatible con diagrams.net |
| `xournalpp` | Notas a mano y anotación de PDF — ideal para tablets gráficas |
| `pinta` | Editor de imágenes simple al estilo Paint.NET — recortes, capas básicas, filtros |
| `gnome-calculator` | Calculadora con modo científico, programador y conversión de unidades |

### Desarrollo

| Paquete | Descripción |
|---|---|
| `nvim` | Neovim — editor modal extensible, base para configuraciones como LazyVim |
| `omarchy-nvim` | ~~Configuración Neovim de Omarchy~~ **Excluido — repo Omarchy** |
| `lazygit` | Interfaz TUI para git — gestiona commits, branches, diffs y stash de forma visual en terminal |
| `github-cli` | CLI oficial de GitHub — crea PRs, issues y gestiona repos desde terminal |
| `rust` | Lenguaje Rust con toolchain completo (cargo, rustc, rustfmt) |
| `llvm` | Infraestructura de compiladores LLVM — requerida por algunas dependencias Rust y C++ |
| `clang` | Compilador C/C++ basado en LLVM — alternativa a GCC con mejores mensajes de error |
| `dotnet-runtime-9.0` | Runtime .NET 9.0 — necesario para ejecutar apps .NET sin compilar |
| `ruby` | Lenguaje Ruby con intérprete y gems |
| `luarocks` | Gestor de paquetes Lua — instala módulos Lua (usados por Neovim) |
| `mise` | Gestor de versiones de herramientas (Node, Python, Ruby, etc.) — alternativa a nvm/pyenv/rbenv en uno |
| `tree-sitter-cli` | Generador de parsers incremental — usado por Neovim para syntax highlighting avanzado |
| `python-poetry-core` | Núcleo de Poetry — gestión de dependencias y empaquetado Python |
| `python-terminaltexteffects` | Efectos visuales animados en terminal con Python |
| `python-gobject` | Bindings Python para GTK/GLib — necesario para scripts que interactúan con apps GNOME |
| `mariadb-libs` | Librerías cliente MariaDB — permite a apps Python/Ruby/Rust conectarse a MySQL/MariaDB |
| `postgresql-libs` | Librerías cliente PostgreSQL — permite a apps conectarse a PostgreSQL |
| `libqalculate` | Biblioteca de cálculo matemático avanzado con soporte de unidades y conversiones |
| `libyaml` | Biblioteca C para parseo de YAML — dependencia de muchas apps Ruby y Python |
| `libsecret` | API para almacenar credenciales en gnome-keyring desde apps y scripts |

### Contenedores y red

| Paquete | Descripción |
|---|---|
| `docker` | Motor de contenedores — ejecuta apps aisladas en contenedores Linux |
| `docker-buildx` | Plugin BuildX — construye imágenes multi-arquitectura (amd64, arm64) |
| `docker-compose` | Orquestación declarativa de contenedores con archivos YAML |
| `lazydocker` | Interfaz TUI para Docker — gestiona contenedores, imágenes y redes de forma visual desde terminal |
| `ufw` | Firewall simplificado — configura iptables/nftables con comandos legibles. Reglas: deny incoming, allow outgoing |
| `ufw-docker` | Reglas adicionales para que UFW funcione correctamente con Docker (evita que Docker bypasee el firewall) |
| `socat` | Relay de sockets — conecta puertos, sockets Unix, pipes y conexiones TCP/UDP de forma versátil |

### Inteligencia artificial

| Paquete | Descripción |
|---|---|
| `claude-code` | CLI oficial de Claude Code (Anthropic) — asistente de IA integrado en terminal para tareas de desarrollo |
| `aether` | ~~Herramienta IA Omarchy~~ **Excluido — repo Omarchy** |
| `tobi-try` | ~~Herramienta IA Omarchy~~ **Excluido — repo Omarchy** |

### Impresión

| Paquete | Descripción |
|---|---|
| `cups` | Sistema de impresión CUPS (Common Unix Printing System) — gestiona impresoras locales y en red |
| `cups-browsed` | Descubre impresoras disponibles en la red local automáticamente |
| `cups-filters` | Filtros de conversión de formatos para CUPS (PDF, PostScript, raster) |
| `cups-pdf` | Impresora virtual que genera un PDF en `~/PDF/` al "imprimir" desde cualquier app |
| `system-config-printer` | Interfaz gráfica para añadir y configurar impresoras en CUPS |

### Bluetooth y conectividad

| Paquete | Descripción |
|---|---|
| `bluetui` | Gestor de Bluetooth en TUI — alternativa a blueman desde terminal |
| `bolt` | Autorización y gestión de dispositivos Thunderbolt/USB4 |
| `impala` | Gestor de redes WiFi en TUI — alternativa a nmtui |
| `wiremix` | Mezclador de audio PipeWire en TUI — controla volumen por app y selecciona dispositivos de salida/entrada (`Super+Ctrl+A`) |

### Autenticación

| Paquete | Descripción |
|---|---|
| `polkit-gnome` | Agente gráfico de PolicyKit. Sin él, las apps GUI que necesitan privilegios (montar discos, cambiar red, gestionar paquetes) **fallan silenciosamente** sin dar ningún error. polkit-gnome muestra el diálogo de contraseña para autorizar esas operaciones. |
| `gnome-keyring` | Almacén cifrado de credenciales del sistema: contraseñas de sitios web, tokens de apps, claves WiFi y claves SSH. Sin él, **cada vez que se reinicia la sesión las apps pierden sus credenciales** y vuelven a pedirlas. Con integración PAM se desbloquea automáticamente al hacer login — sin diálogos extra. |
| `1password-beta` | Gestor de contraseñas 1Password (beta) |
| `1password-cli` | CLI de 1Password |

### Entrada de texto internacional

| Paquete | Descripción |
|---|---|
| `fcitx5` | ~~Framework de métodos de entrada asiáticos~~ **Excluido — no requerido** |
| `fcitx5-gtk` | ~~Módulo GTK~~ **Excluido** |
| `fcitx5-qt` | ~~Módulo Qt~~ **Excluido** |

### OCR

| Paquete | Descripción |
|---|---|
| `tesseract` | Motor de reconocimiento óptico de caracteres |
| `tesseract-data-eng` | Datos de entrenamiento OCR para inglés |

### Utilidades CLI

| Paquete | Descripción |
|---|---|
| `ripgrep` | Búsqueda de texto ultrarrápida |
| `fd` | Búsqueda de archivos moderna |
| `bat` | Visor de archivos con resaltado de sintaxis |
| `eza` | Listado de archivos moderno con iconos |
| `dust` | Analizador de uso de disco visual |
| `jq` | Procesador JSON desde CLI |
| `gum` | Herramienta para scripts interactivos con menús |
| `xmlstarlet` | Procesamiento XML desde CLI |
| `usage` | Generador de páginas de ayuda para CLIs |
| `yay` | Auxiliar AUR |

---

## Paquetes adicionales — no presentes en Omarchy

Estos paquetes no forman parte del script original de Omarchy. Se agregan en base a las necesidades del flujo de trabajo.

### Navegadores

| Paquete | Repo | Descripción |
|---|---|---|
| `firefox` | Oficial | Navegador libre Mozilla Firefox |
| `google-chrome` | AUR | Chrome oficial de Google |
| `brave-bin` | AUR | Chromium con bloqueador de anuncios nativo |
| `opera` | AUR | Opera con VPN integrada |
| `microsoft-edge-stable-bin` | AUR | Microsoft Edge estable |

### Terminal

| Paquete | Repo | Descripción |
|---|---|---|
| `alacritty` | Oficial | Terminal GPU-accelerated, nativa Wayland — para uso local |

> Hyprland provee tiling nativo de ventanas, por lo que `alacritty` como terminal simple es suficiente para uso local. `tmux` queda reservado exclusivamente para sesiones remotas SSH, evitando conflictos de teclas por sesiones anidadas.

### Desarrollo

| Paquete | Repo | Descripción |
|---|---|---|
| `visual-studio-code-bin` | AUR | VSCode — build oficial Microsoft |
| `python-antigravity` | AUR | Python Easter egg — `import antigravity` abre el cómic xkcd #353 (Python Flies!) |

### Inteligencia artificial

| Paquete | Repo | Descripción |
|---|---|---|
| `aichat` | AUR | CLI unificada para múltiples proveedores de IA: OpenAI/ChatGPT, Gemini, Claude, Mistral, Ollama y más desde una sola herramienta |
| `gemini-cli` | AUR | CLI oficial de Google para Gemini |

### Virtualización (según wiki oficial CachyOS)

Fuente: [wiki.cachyos.org — QEMU and VMM Setup](https://wiki.cachyos.org/es/virtualization/qemu_and_vmm_setup/)

| Paquete | Repo | Descripción |
|---|---|---|
| `qemu-full` | Oficial | QEMU completo con soporte para múltiples arquitecturas |
| `virt-manager` | Oficial | Interfaz gráfica para gestión de máquinas virtuales |
| `swtpm` | Oficial | Emulador de TPM por software — requerido para Windows 11 en VM |

El script ejecuta los siguientes pasos de configuración post-instalación:

```bash
echo 'firewall_backend = "iptables"' | sudo tee -a /etc/libvirt/network.conf
sudo usermod -aG libvirt $USER
systemctl enable --now libvirtd.socket
sudo virsh net-autostart default
```

---

## Configuración de SDDM

El script instala `sddm` como display manager con el tema `sddm-astronaut-theme` — pantalla de login gráfica con estética oscura y colores neón, habitual en setups CachyOS/Hyprland.

### Configuración del tema

El script crea `/etc/sddm.conf.d/hyprland.conf` automáticamente. Para modificarlo después:

```bash
sudo vim /etc/sddm.conf.d/hyprland.conf
```

Contenido:

```ini
[Theme]
Current=sddm-astronaut-theme
```

Después de cualquier cambio, recarga el servicio:

```bash
sudo systemctl restart sddm.service
```

---

### Personalización del tema astronaut

El tema tiene su propio archivo de configuración en:

```bash
/usr/share/sddm/themes/sddm-astronaut-theme/theme.conf
```

Para personalizarlo sin perder los cambios al actualizar el paquete, copia la configuración al directorio local:

```bash
sudo mkdir -p /etc/sddm.conf.d
sudo cp /usr/share/sddm/themes/sddm-astronaut-theme/theme.conf \
        /etc/sddm.conf.d/sddm-astronaut-theme.conf
```

#### Opciones principales de theme.conf

| Opción | Descripción | Ejemplo |
|---|---|---|
| `Background` | Imagen de fondo | `"Backgrounds/background.png"` |
| `DimBackgroundImage` | Opacidad de oscurecimiento | `"0.0"` a `"1.0"` |
| `BlurBackground` | Desenfoque del fondo | `"true"` / `"false"` |
| `PartialBlur` | Desenfoque solo en el panel | `"true"` / `"false"` |
| `FormPosition` | Posición del formulario | `"center"` / `"left"` / `"right"` |
| `AccentColor` | Color de acento | `"#cba6f7"` (morado CachyOS) |
| `Font` | Fuente | `"Noto Sans"` |
| `FontSize` | Tamaño de fuente | `"12"` |

Para cambiar el fondo coloca la imagen en:

```bash
/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/
```

---

### Selector de fondo SDDM (rofi)

El script instala un switcher de fondos de pantalla para SDDM accesible desde el escritorio, con el mismo estilo visual que el selector de temas de Omarchy.

**Componentes instalados:**

| Componente | Ruta | Descripción |
|---|---|---|
| Helper privilegiado | `/usr/local/bin/sddm-apply-bg` | Edita la clave `Background=` en `/etc/sddm.conf.d/sddm-astronaut-theme.conf` |
| Regla sudoers | `/etc/sudoers.d/sddm-bg` | Permite ejecutar `sddm-apply-bg` sin contraseña (NOPASSWD) |
| Script de usuario | `~/.local/bin/sddm-bg-switcher` | Lista los fondos disponibles via rofi y llama al helper |
| Entrada de escritorio | `~/.local/share/applications/sddm-bg-switcher.desktop` | Visible en el lanzador de aplicaciones |

**Uso:**

Lanzar `sddm-bg-switcher` desde rofi (`Super+Space`) o desde la entrada en el lanzador. Muestra un menú con todos los archivos en `/usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/`. Al seleccionar uno, el cambio se aplica de inmediato en el archivo de configuración — activo en el próximo login de SDDM.

**Para agregar fondos propios:**

```bash
sudo cp mi-fondo.jpg /usr/share/sddm/themes/sddm-astronaut-theme/Backgrounds/
```

El archivo aparecerá automáticamente en el menú del switcher.

---

### Sesiones disponibles

SDDM detecta automáticamente las sesiones de escritorio en:

- `/usr/share/wayland-sessions/` — sesiones Wayland (incluye `hyprland-uwsm.desktop`)
- `/usr/share/xsessions/` — sesiones X11

Para ver las sesiones disponibles:

```bash
ls /usr/share/wayland-sessions/
```

---

### Sesión correcta: Hyprland (uwsm-managed)

SDDM muestra dos entradas de sesión Hyprland porque el paquete `hyprland` instala su propio `.desktop` y el paquete `uwsm` instala el suyo:

| Sesión | Archivo | Uso |
|---|---|---|
| **Hyprland (uwsm-managed)** | `hyprland-uwsm.desktop` | Correcto — Hyprland bajo UWSM con integración systemd |
| Hyprland | `hyprland.desktop` | Incorrecto para esta configuración — sin UWSM, el autostart no funciona |

Siempre selecciona **Hyprland (uwsm-managed)**. La sesión sin UWSM dejará el autostart (waybar, swaybg, mako, etc.) sin ejecutarse.

Para evitar confusión, el script oculta `hyprland.desktop` añadiéndole `NoDisplay=true` e instala un hook de pacman que lo re-aplica en cada actualización.

> **Importante:** no se debe eliminar `hyprland.desktop`. El comando `uwsm start -e -D Hyprland hyprland.desktop` necesita leer ese archivo para obtener el entorno del compositor. Borrarlo hace que UWSM falle al iniciar la sesión.

```bash
# Ocultar (sin eliminar)
sudo grep -q 'NoDisplay=true' /usr/share/wayland-sessions/hyprland.desktop || \
    sudo sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /usr/share/wayland-sessions/hyprland.desktop
```

```ini
# /etc/pacman.d/hooks/hyprland-hide-plain-session.hook
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = hyprland

[Action]
Description = Ocultar sesion Hyprland sin UWSM de SDDM...
When = PostTransaction
Exec = /bin/bash -c "grep -q 'NoDisplay=true' /usr/share/wayland-sessions/hyprland.desktop || sed -i '/^\[Desktop Entry\]/a NoDisplay=true' /usr/share/wayland-sessions/hyprland.desktop"
```

---

### Scripts de pre/post sesión

SDDM permite ejecutar scripts al iniciar y cerrar una sesión Wayland mediante:

```bash
/usr/share/sddm/scripts/wayland-session
```

Este archivo es un wrapper. Para agregar lógica propia sin modificarlo directamente, usa `Environment` en la configuración de SDDM o configura los hooks de UWSM (recomendado para Hyprland).

---

### Configuración con múltiples monitores

SDDM corre como servidor de display y muestra la pantalla de login en el monitor principal (determinado por el firmware/randr). Los monitores secundarios quedan inactivos hasta que Hyprland arranca e inicializa todos los outputs.

Para cambiar qué monitor muestra el login, configura el monitor primario en BIOS/UEFI o mediante reglas de udev antes del arranque del DM.

Los fondos de pantalla por monitor son gestionados por Hyprland tras el login (con `swaybg` o `hyprpaper` en el autostart), no por SDDM.

---

## Inicialización de hyprland.lua

Hyprland genera un `~/.config/hypr/hyprland.conf` marcado como `autogenerated=1` en el primer arranque. A partir de Hyprland 0.46+ el config real es `hyprland.lua` (Lua API), pero el `.conf` autogenerado lo sobreescribe si ambos coexisten.

El script `install-hyprland-desktop.sh` detecta y corrige esta situación al inicio (`init_hyprland_config`):

1. Si existe `hyprland.conf` con `autogenerated=1` → lo renombra a `hyprland.conf.stub` para que no interfiera
2. Si `hyprland.lua` tiene menos de 100 líneas (fragmento generado por Hyprland) → lo reemplaza con la config completa de `/usr/share/hypr/hyprland.lua`
3. Agrega el bloque de autostart al `hyprland.lua`:

```lua
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- waybar")
    hl.exec_cmd("uwsm app -- hypridle")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("uwsm app -- swaybg -m fill -i ~/.config/omarchy/current/background")
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
end)
```

> Si el script se ejecuta con `hyprland.lua` ya completo (segunda ejecución o instalación previa), lo detecta por el número de líneas y no lo sobreescribe — es idempotente.

### Ajustes de layout aplicados por el script

Tras copiar `hyprland.lua`, el script sobreescribe los siguientes valores del bloque `general {}` que difieren del default del paquete:

| Parámetro | Default Hyprland | Valor aplicado | Motivo |
|---|---|---|---|
| `gaps_out` | 20 | **10** | El margen de 20 px es excesivo; 10 px es el valor validado visualmente en pantallas medianas |

```bash
sed -i 's/gaps_out\s*=\s*[0-9]\+/gaps_out = 10/' "$lua"
```

---

## Configuración de Alacritty

Alacritty 0.13+ usa formato TOML. El archivo de configuración se crea en `~/.config/alacritty/alacritty.toml`.

### Tema Catppuccin Mocha

```bash
mkdir -p ~/.config/alacritty/themes
curl -Lo ~/.config/alacritty/themes/catppuccin-mocha.toml \
    "https://raw.githubusercontent.com/catppuccin/alacritty/main/catppuccin-mocha.toml"
```

Verificar descarga:

```bash
head -3 ~/.config/alacritty/themes/catppuccin-mocha.toml
```

Salida esperada:

```
[colors.primary]
background = "#1e1e2e"
foreground = "#cdd6f4"
```

### Archivo de configuración

```bash
vim ~/.config/alacritty/alacritty.toml
```

Contenido:

```toml
[general]
import = ["~/.config/alacritty/themes/catppuccin-mocha.toml"]

[window]
decorations = "none"
opacity = 0.95
padding = { x = 8, y = 8 }

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold   = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size   = 13.0

[cursor]
style = { shape = "Block", blinking = "On" }

[scrolling]
history = 10000
```

Alacritty recarga la configuración automáticamente al guardar el archivo.

### Actualizar variables de aplicaciones en Hyprland

`~/.config/hypr/hyprland.lua` define las apps por defecto en tres variables. El script las ajusta independientemente del valor original:

```bash
sed -i 's|^local terminal\s*=.*|local terminal    = "alacritty"|' ~/.config/hypr/hyprland.lua
sed -i 's|^local fileManager\s*=.*|local fileManager = "nautilus"|' ~/.config/hypr/hyprland.lua
sed -i 's|^local menu\s*=.*|local menu        = "rofi -show drun"|' ~/.config/hypr/hyprland.lua
```

Verificar:

```bash
grep -E "^local (terminal|fileManager|menu)" ~/.config/hypr/hyprland.lua
```

Salida esperada:

```
local terminal    = "alacritty"
local fileManager = "nautilus"
local menu        = "rofi -show drun"
```

Estas variables controlan los keybinds:

| Keybind | Variable | App |
|---|---|---|
| `Super + Q` | `terminal` | alacritty |
| `Super + E` | `fileManager` | nautilus |
| `Super + SPACE` | `menu` | rofi -show drun |

Recargar Hyprland para aplicar:

```bash
hyprctl reload
```

> Cualquier cambio en `hyprland.lua` requiere `hyprctl reload` o cerrar sesión para surtir efecto. Esto aplica a todos los cambios de configuración de Hyprland.

### Validación

Presionar `Super + Q` — debe abrir Alacritty. Dentro:

```bash
echo $TERM
```

Salida esperada:

```
alacritty
```

Presionar `Super + SPACE` — debe abrir rofi. Presionar `Super + E` — debe abrir Nautilus.

---

## Super Bash — ble.sh + Oh My Bash

Bash mejorado con las mismas capacidades interactivas de ZSH: resaltado de sintaxis en tiempo real, autocompletado interactivo por Tab y sugerencias grises del historial. Sin cambiar el shell por defecto.

| Componente | Función |
|---|---|
| **ble.sh** | Bash Line Editor — motor de resaltado, autocompletado y sugerencias del historial |
| **Oh My Bash** | Framework de configuración y temas para Bash |

### Cómo funciona el acoplamiento

`ble.sh` se carga con `--noattach` al inicio de `~/.bashrc` para que su núcleo esté disponible antes de que Oh My Bash configure el prompt. `ble-attach` va al final para activarlo sin interferir.

```bash
# Inicio de ~/.bashrc — carga ble.sh sin activar aún
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --noattach 2>/dev/null

# ... configuración de Oh My Bash en el medio ...

# Final de ~/.bashrc — activa ble.sh sobre el prompt de OMB
[[ ${BLE_VERSION-} ]] && ble-attach
```

### Instalación manual

```bash
# ble.sh
git clone --recursive --depth=1 https://github.com/akinomyoga/ble.sh.git /tmp/ble.sh
make -C /tmp/ble.sh install PREFIX=~/.local

# Oh My Bash (no cambia el shell por defecto)
RUNBASH=no CHSH=no KEEP_BASHRC=yes \
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"
```

### Verificación

```bash
bash
```

Al abrir bash debés ver el prompt de Oh My Bash y el resaltado de sintaxis activo. Escribir un comando parcial y presionar `→` o `End` completa con la sugerencia del historial.

---

## Configuración de hyprsunset

Filtro de luz azul integrado en Hyprland. Reduce la temperatura de color de la pantalla para disminuir la fatiga visual. Se ejecuta en el autostart de Hyprland.

### Autostart en hyprland.lua

Agregar en la sección de autostart de `~/.config/hypr/hyprland.lua`:

```lua
hl.exec_cmd("uwsm app -- hyprsunset -t 4500")
```

El valor `-t 4500` indica 4500K — temperatura cálida moderada. Rango orientativo:

| Temperatura | Descripción |
|---|---|
| 6500K | Luz de día (neutro) |
| 4500K | Cálido moderado — uso diario |
| 3500K | Muy cálido — uso nocturno |

Para aplicar el cambio en la sesión actual sin cerrar sesión, ejecutar **desde Alacritty** (dentro de la sesión Hyprland, no por SSH):

```bash
hyprctl reload
hyprsunset -t 4500 &
```

> El autostart solo se ejecuta al iniciar sesión. `hyprctl reload` aplica la nueva config pero no relanza los procesos de autostart — hay que iniciarlos manualmente si se quiere activar en la sesión actual.
>
> `uwsm app --` es el wrapper para el autostart de Hyprland. Para pruebas manuales usar `hyprsunset -t 4500 &` directamente desde una terminal dentro de la sesión gráfica — no funciona por SSH porque requiere acceso al compositor Wayland.

### Validación

Ejecutar desde Alacritty:

```bash
pgrep -a hyprsunset
```

Salida esperada:

```
12345 hyprsunset -t 4500
```

La pantalla debe mostrar un tono ligeramente más cálido (amarillento) respecto al blanco neutro.

Para detenerlo temporalmente:

```bash
pkill hyprsunset
```

---

## Configuración de hyprlock e hypridle

`hyprlock` es la pantalla de bloqueo nativa de Hyprland. `hypridle` es el daemon de inactividad que la dispara automáticamente. Ambos están instalados por `install-cachyos-hyprland.sh` y `hypridle` ya aparece en el autostart de `hyprland.lua`.

### Configurar hypridle

Crear `~/.config/hypr/hypridle.conf`:

```bash
cat > ~/.config/hypr/hypridle.conf << 'EOF'
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = hyprlock
    after_sleep_cmd = hyprctl dispatch dpms on
}

listener {
    timeout = 300
    on-timeout = hyprlock
}

listener {
    timeout = 600
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}

listener {
    timeout = 1800
    on-timeout = systemctl suspend
}
EOF
```

| Timeout | Acción |
|---|---|
| 300 s (5 min) | Bloquea pantalla con hyprlock |
| 600 s (10 min) | Apaga la pantalla (DPMS off) |
| 1800 s (30 min) | Suspende el equipo |

### Ajustar tiempos desde rofi: «Pantalla y energía»

Para cambiar estos valores sin editar `hypridle.conf` a mano, la función `install_idle_settings()` (en `install-hyprland-desktop.sh`) despliega el script `/usr/local/bin/idle-settings` y un lanzador **«Pantalla y energía»** accesible desde rofi (`Super + Space`) o el menú de aplicaciones.

Al ejecutarlo abre menús rofi consecutivos para fijar:

1. **Bloquear pantalla** — tiempo tras el cual se activa `hyprlock`.
2. **Suspender equipo** — tiempo tras el cual se ejecuta `systemctl suspend`.
3. **Hibernar equipo** — tiempo tras el cual se ejecuta `systemctl hibernate`. Este menú **solo aparece si el sistema soporta hibernación**: `disk` presente en `/sys/power/state` y swap activo, lo que depende de haber instalado con `USE_HIBERNATE=true` en `install-base.sh` (swap offset + `resume=UUID` en GRUB + hook `resume` en mkinitcpio).

> [!IMPORTANT]
> **Requisito crítico validado:** el hook `resume` debe estar presente en `HOOKS` de `/etc/mkinitcpio.conf`, **después de `filesystems`**, para que el kernel resuelva el parámetro `resume=UUID=...` al dispositivo real durante el initramfs. Sin él, `/sys/power/resume` queda en `0:0` y `systemctl hibernate` falla con `Invalid resume config`. El script `install-base.sh` lo agrega automáticamente cuando `USE_HIBERNATE=true`.

El script regenera `hypridle.conf`, deriva el apagado de pantalla (DPMS) 5 minutos después del bloqueo si cabe antes de suspender, y reinicia `hypridle.service` en caliente (sin cerrar sesión). Valida que los tiempos sean crecientes (`bloqueo ≤ suspensión ≤ hibernación`); si no lo son, muestra una notificación de error y no aplica cambios.

> Opciones de cada menú: 5, 10, 15, 20, 30, 60, 120 minutos o «Nunca» (desactiva ese listener).

### Configurar hyprlock

Crear `~/.config/hypr/hyprlock.conf` con tema Catppuccin Mocha:

```bash
cat > ~/.config/hypr/hyprlock.conf << 'EOF'
general {
    disable_loading_bar = true
    hide_cursor = true
    grace = 0
}

background {
    monitor =
    path = screenshot
    blur_passes = 3
    blur_size = 7
}

input-field {
    monitor =
    size = 300, 50
    outline_thickness = 2
    dots_size = 0.2
    dots_spacing = 0.2
    outer_color = rgb(cba6f7)
    inner_color = rgb(1e1e2e)
    font_color = rgb(cdd6f4)
    fade_on_empty = true
    placeholder_text = <i>Contraseña...</i>
    rounding = 8
    position = 0, -100
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:1000] echo "<b>$(date +'%H:%M')</b>"
    color = rgba(205, 214, 244, 1.0)
    font_size = 72
    font_family = JetBrainsMono Nerd Font
    position = 0, 300
    halign = center
    valign = center
}

label {
    monitor =
    text = cmd[update:60000] echo "<b>$(date +'%A, %d de %B')</b>"
    color = rgba(166, 173, 200, 1.0)
    font_size = 18
    font_family = JetBrainsMono Nerd Font
    position = 0, 200
    halign = center
    valign = center
}
EOF
```

### Keybinding Super+Ctrl+L

Agregar en `~/.config/hypr/hyprland.lua` junto a los demás binds principales:

```lua
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))
```

Aplicar cambios:

```bash
hyprctl reload
```

> `loginctl lock-session` no funciona en este setup porque requiere un handler de sesión registrado vía D-Bus. Usar `hyprlock` directo.

### Validación

```bash
pgrep -a hypridle
```

Salida esperada:

```
1234 hypridle
```

Presionar `Super+L`: debe aparecer la pantalla de bloqueo con fondo difuminado, reloj y campo de contraseña. Ingresar la contraseña y presionar Enter para desbloquear.

---

## eww — monitor del sistema en el escritorio

`eww` (Elkowar's Wacky Widgets) es un compositor de widgets nativo Wayland que muestra información del sistema superpuesta en el escritorio, en la esquina superior derecha bajo la waybar. A diferencia de Conky (que requería XWayland), eww corre nativamente en Wayland y su ventana se posiciona en la capa `bottom` — siempre debajo de todas las ventanas y visible en todos los workspaces.

### Información que muestra

| Sección | Datos |
|---|---|
| Reloj | Hora con segundos y fecha completa |
| CPU | Uso %, temperatura del paquete, frecuencia promedio |
| Memoria | RAM y swap usados / total con barra de progreso |
| Disco | Pool BTRFS usado / total, temperatura NVMe |
| Red | IP LAN IPv4 e IPv6 link-local, IP WAN pública IPv4 e IPv6, velocidad UP/DN |
| GPU Intel Iris Xe | Engine Render % + RC6 %, frecuencia activa, potencia GPU y total |

### Archivos de configuración

| Archivo | Función |
|---|---|
| `~/.config/eww/eww.yuck` | Layout del widget — definición de ventana, secciones y datos |
| `~/.config/eww/eww.scss` | Estilos CSS — colores Catppuccin Mocha, tipografía, barras |
| `/usr/local/bin/eww-sysinfo` | Script Python: lee CPU/RAM/disco/red/GPU y emite JSON cada 3 s |
| `/usr/local/bin/eww-net-speed` | Script bash: mide velocidad UP/DN durante 1 s y emite JSON |
| `/usr/local/bin/eww-wan` | Script bash: obtiene IP WAN pública (IPv4 e IPv6) cada 5 min |
| `/etc/sudoers.d/intel-gpu-top` | Permite ejecutar `intel_gpu_top` sin contraseña (necesario para eww-sysinfo) |

### Uso

eww arranca automáticamente con el escritorio vía `hyprland.lua`. Para controlarlo manualmente:

```bash
# Abrir el widget sysmon
eww open sysmon
```

```bash
# Cerrar el widget
eww close sysmon
```

```bash
# Ver estado de todos los widgets
eww state
```

```bash
# Reiniciar el daemon (tras editar eww.yuck o eww.scss)
eww kill; eww open sysmon
```

### Personalización

Editar `~/.config/eww/eww.scss` para ajustar colores o tipografía, y `~/.config/eww/eww.yuck` para modificar el layout. Los colores siguen la paleta Catppuccin Mocha:

- `#89dceb` — encabezados de sección (Sky)
- `#cba6f7` — reloj (Mauve)
- `#cdd6f4` — texto base (Text)
- `#a6adc8` — etiquetas de fila (Subtext0)

Tras cualquier cambio, reiniciar el daemon:

```bash
eww kill; eww open sysmon
```

---

## Configuración de wiremix

`wiremix` es un mixer TUI para PipeWire que permite controlar el volumen por aplicación desde el teclado, sin salir de la sesión. Se abre con `Super+Ctrl+A`.

### Instalación

```bash
paru -S wiremix
```

### Keybinding

Agregar en `~/.config/hypr/hyprland.lua`:

```lua
hl.bind(mainMod .. " + CTRL + A", hl.dsp.exec_cmd("alacritty -e wiremix"))
```

Aplicar:

```bash
hyprctl reload
```

### Validación

```bash
wiremix
```

Presionar `Super+Ctrl+A`: debe abrir Alacritty con la interfaz TUI de wiremix.

> wiremix muestra streams activos (aplicaciones reproduciendo audio). Si no hay audio en reproducción, la lista aparece vacía o solo con los sinks/sources — es el comportamiento esperado. Para gestión de dispositivos y perfiles de hardware usar `pavucontrol` (clic en ícono de audio de waybar).

---

## Configuración de mako

`mako` es el daemon de notificaciones para Wayland. Está integrado en el autostart de Hyprland y los keybindings de descarte ya están configurados (`Super+,` y `Super+Shift+,`). Solo requiere el archivo de configuración con el tema Catppuccin Mocha.

### Archivo de configuración

`~/.config/mako/config`:

```ini
font=JetBrainsMono Nerd Font 12
background-color=#1e1e2e
text-color=#cdd6f4
border-color=#cba6f7
progress-color=over #313244
border-size=2
border-radius=8
default-timeout=5000
ignore-timeout=0
sort=-time
layer=overlay
width=300
margin=10
padding=15
max-visible=5

[urgency=high]
border-color=#f38ba8
default-timeout=0
```

Colores Catppuccin Mocha: fondo Base (`#1e1e2e`), texto Text (`#cdd6f4`), borde Mauve (`#cba6f7`), urgencia alta Red (`#f38ba8`).

### Aplicar sin reiniciar

```bash
makoctl reload
```

### Validación

```bash
notify-send "Mako test" "Catppuccin Mocha activo" --urgency=normal
notify-send "Urgencia alta" "Borde rojo" --urgency=critical
```

La primera notificación aparece con borde morado y desaparece a los 5 s. La segunda con borde rojo y no cierra sola. `Super+,` descarta la última; `Super+Shift+,` descarta todas.

---

## Configuración de rofi

`rofi` es el lanzador de aplicaciones — reemplaza Walker de Omarchy. Se abre con `Super+Space`. La versión instalada es v2.0.

> [!IMPORTANT]
> **rofi está integrado al sistema de temas unificado (omarchy).** El tema NO es fijo: lo genera `theme-apply` a partir del tema activo (igual que terminal, waybar, hyprland y wallpaper). Al cambiar de tema con `Super+Shift+T`, rofi cambia junto con todo lo demás.

### Cómo funciona la integración

1. **Template:** `~/.local/share/omarchy-local/themed/rofi.rasi.tpl` define la estructura del tema con placeholders (`{{ background }}`, `{{ accent }}`, `{{ foreground }}`, `{{ color0 }}`, `{{ color8 }}`, `{{ selection_background }}`).
2. **Generación:** `theme-apply` rellena el template con los colores del tema activo (`colors.toml`) y escribe el resultado en `~/.config/omarchy/current/rofi.rasi`.
3. **Config:** `~/.config/rofi/config.rasi` apunta a ese archivo generado con **ruta absoluta** (rofi bajo `uwsm` no expande `~` de forma fiable).

`~/.config/rofi/config.rasi`:

```rasi
configuration {
    modi:        "drun,run,window";
    show-icons:  true;
    icon-theme:  "Papirus-Dark";
    drun-display-format: "{name}";
    font:        "JetBrainsMono Nerd Font 12";
}

@theme "/home/usuario/.config/omarchy/current/rofi.rasi"
```

`~/.local/share/omarchy-local/themed/rofi.rasi.tpl` (mapeo de placeholders → colores del tema):

```rasi
* {
    bg:       {{ background }};
    bg-alt:   {{ color0 }};
    fg:       {{ foreground }};
    fg-dim:   {{ color8 }};
    accent:   {{ accent }};
    selected: {{ selection_background }};
}

window {
    width:            35%;
    padding:          0;
    border:           2px solid;
    border-color:     @accent;
    border-radius:    12px;
    background-color: @bg;
}

mainbox {
    padding:          8px;
    background-color: transparent;
}

inputbar {
    padding:          8px 12px;
    margin:           0 0 8px 0;
    border-radius:    8px;
    background-color: @bg-alt;
    children:         [prompt, entry];
}

prompt {
    padding:          0 8px 0 0;
    color:            @accent;
    background-color: transparent;
}

entry {
    color:            @fg;
    background-color: transparent;
}

listview {
    lines:            8;
    columns:          1;
    fixed-height:     false;
    spacing:          4px;
    background-color: transparent;
}

element {
    padding:          8px 12px;
    border-radius:    6px;
    background-color: transparent;
    color:            @fg;
}

element selected {
    background-color: @selected;
    color:            @bg;
}

element-icon {
    size:             24px;
    background-color: transparent;
}

element-text {
    background-color: transparent;
    color:            inherit;
}
```

> [!IMPORTANT]
> **`element selected` usa `@bg` (no `@fg`) como color de texto.** En varios temas (ethereal, everforest, hackerman, last-horizon, osaka-jade, vantablack, catppuccin) el `selection_background` coincide con o es muy similar al `foreground`, haciendo el nombre del ítem seleccionado invisible. Como todos esos temas tienen fondo oscuro (`@bg`) y selección clara (`@selected`), usar `@bg` garantiza contraste en los 22 temas disponibles. Validado con `Super+Shift+T`.

> [!WARNING]
> El bind `Super+Space` DEBE ejecutar **`rofi -show drun`**, no `rofi` a secas. Sin `-show drun` rofi abre una ventana vacía donde no se puede seleccionar nada. En `hyprland.lua`: `local menu = "rofi -show drun"`.

### Validación

Presionar `Super+Space`: aparece el lanzador centrado con los colores del **tema activo** (con `nord`: fondo `#2e3440`, borde azul `#81a1c1`), iconos Papirus, y aplicaciones seleccionables. La búsqueda filtra en tiempo real. Cambiar de tema con `Super+Shift+T` y reabrir: rofi refleja el nuevo tema.

---

## Configuración de cliphist

`cliphist` es el gestor de historial de portapapeles de Wayland. En Omarchy se accede con `Super+Ctrl+V`. El pipeline integra `wl-clipboard` para escuchar el portapapeles y `rofi` para seleccionar la entrada a recuperar.

### Instalación

```bash
paru -S cliphist wl-clipboard
```

### Configuración en Hyprland

Se necesitan dos cambios en `~/.config/hypr/hyprland.lua`: un daemon en autostart que almacena cada copia en la base de datos, y un keybinding para invocar el historial.

**Autostart** — agregar dentro del bloque `hl.on("hyprland.start", ...)`:

```lua
hl.exec_cmd("wl-paste --type text --watch cliphist store")
```

**Keybinding** — agregar junto a los otros bindings `CTRL`:

```lua
hl.bind(mainMod .. " + CTRL + V", hl.dsp.exec_cmd("bash -c 'cliphist list | rofi -dmenu -p Portapapeles | cliphist decode | wl-copy'"))
```

### Validación

1. Copiar varios textos distintos (`Ctrl+C` en cualquier app)
2. Presionar `Super+Ctrl+V` — aparece rofi listando el historial
3. Seleccionar una entrada — queda en el portapapeles
4. Pegar con `Ctrl+V` en cualquier app — el texto recuperado aparece

---

## Configuración del wallpaper

`swaybg` ya está activo desde el autostart de Hyprland. Solo se necesita cambiar la imagen genérica por el wallpaper oficial del tema catppuccin de Omarchy y desactivar el fondo por defecto de Hyprland.

### Fondos disponibles (tema catppuccin de Omarchy)

| Archivo | Resolución | Descripción |
|---|---|---|
| `1-totoro.png` | 3840×2160 | Primer fondo (default Omarchy) |
| `2-waves.png` | 3840×2160 | Ondas — el elegido |
| `3-blue-eye.png` | 3840×2160 | Ojo azul |

Los fondos están en el repo de Omarchy en `themes/catppuccin/backgrounds/`.

### Instalación

Crear el directorio y descargar el wallpaper:

```bash
mkdir -p ~/.local/share/backgrounds
curl -L 'https://raw.githubusercontent.com/basecamp/omarchy/dev/themes/catppuccin/backgrounds/2-waves.png' \
    -o ~/.local/share/backgrounds/omarchy-catppuccin-2-waves.png
```

Verificar:

```bash
file ~/.local/share/backgrounds/omarchy-catppuccin-2-waves.png
```

Salida esperada:

```
~/.local/share/backgrounds/omarchy-catppuccin-2-waves.png: PNG image data, 3840 x 2160, 8-bit/color RGB, non-interlaced
```

### Configuración en hyprland.lua

Actualizar la línea de swaybg en el autostart de `~/.config/hypr/hyprland.lua`:

```lua
-- Antes:
hl.exec_cmd("uwsm app -- swaybg -i /usr/share/hypr/wall0.png")

-- Después:
hl.exec_cmd("uwsm app -- swaybg -i ~/.local/share/backgrounds/omarchy-catppuccin-2-waves.png -m fill")
```

La opción `-m fill` escala la imagen para cubrir toda la pantalla manteniendo la relación de aspecto.

### Desactivar el fondo por defecto de Hyprland

Sin este cambio, al iniciar sesión aparece brevemente el fondo de Hyprland antes de que swaybg arranque. En la sección `misc` de `hyprland.lua`:

```lua
-- Cambiar:
disable_hyprland_logo   = false,

-- Por:
disable_hyprland_logo   = true,
```

### Aplicar sin reiniciar sesión

```bash
pkill -x swaybg
setsid swaybg -i ~/.local/share/backgrounds/omarchy-catppuccin-2-waves.png -m fill &
```

El cambio de `disable_hyprland_logo` aplica en el próximo inicio de sesión.

### Validación

El wallpaper debe aparecer inmediatamente. Al cerrar sesión (`Super+M`) y volver a entrar, debe aparecer directamente el wallpaper sin el fondo de Hyprland en medio.

---

## Aplicaciones del escritorio

Aplicaciones del stack Omarchy adaptadas a CachyOS. Se instalan con paru y se configuran como handlers xdg por defecto donde aplica.

### Instalación

```bash
paru -S imv mpv signal-desktop obsidian drawio-desktop
```

Verificar todas:

```bash
for pkg in imv mpv obsidian typora signal-desktop drawio-desktop; do
    pacman -Q $pkg 2>/dev/null || echo "$pkg: FALTA"
done
```

### Handlers xdg por defecto

Establecer `imv` como visor de imágenes y `mpv` como reproductor de video (mpv se establece solo al instalarse):

```bash
for mime in image/jpeg image/png image/gif image/webp image/svg+xml image/bmp image/tiff; do
    xdg-mime default imv.desktop $mime
done
```

Verificar:

```bash
xdg-mime query default image/jpeg
xdg-mime query default video/mp4
```

Salida esperada:

```
imv.desktop
mpv.desktop
```

### Aplicaciones

| Aplicación | Uso | Lanzador |
|---|---|---|
| `imv` | Visor de imágenes Wayland | `imv <archivo>` o desde gestor de archivos |
| `mpv` | Reproductor multimedia | `mpv <archivo>` o desde gestor de archivos |
| `obsidian` | Gestión de conocimiento en Markdown — notas, wiki personal, enlaces entre documentos | rofi / `obsidian` |
| `typora` | Editor Markdown WYSIWYG — previsualización en tiempo real sin panel dividido | rofi / `typora` |
| `signal-desktop` | Mensajería cifrada extremo a extremo | rofi / `signal-desktop` |
| `drawio-desktop` | Editor de diagramas: flujos, arquitecturas, redes, UML — compatible con draw.io/diagrams.net | rofi / `drawio-desktop` |

### Validación

```bash
imv /usr/share/pixmaps/*.png
```

Salida esperada: ventana con visor de imágenes navegable con flechas.

```bash
signal-desktop &
```

Salida esperada: ventana de Signal.

---

## Sistema de temas — Nivel 1 (consistencia visual)

Aplica Catppuccin Mocha de forma consistente a todas las capas del escritorio: GTK, Qt, cursor e iconos. El terminal (Alacritty), waybar e hyprlock ya tienen Catppuccin desde sus propias fases.

> El Nivel 2 (switcher de temas con keybinding, estilo Omarchy) se documenta en la sección **Sistema de temas Omarchy**, más abajo.

### Instalación

```bash
paru -S catppuccin-gtk-theme-mocha catppuccin-cursors-mocha papirus-icon-theme nwg-look kvantum
```

### Aplicar tema GTK, iconos y cursor

```bash
gsettings set org.gnome.desktop.interface gtk-theme 'catppuccin-mocha-mauve-standard+default'
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
gsettings set org.gnome.desktop.interface cursor-theme 'catppuccin-mocha-dark-cursors'
gsettings set org.gnome.desktop.interface cursor-size 24
```

Crear `~/.config/gtk-3.0/settings.ini` y `~/.config/gtk-4.0/settings.ini` para apps que no leen gsettings:

```bash
mkdir -p ~/.config/gtk-3.0 ~/.config/gtk-4.0

cat > ~/.config/gtk-3.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=catppuccin-mocha-mauve-standard+default
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=catppuccin-mocha-dark-cursors
gtk-cursor-theme-size=24
gtk-font-name=Sans 11
gtk-application-prefer-dark-theme=1
EOF

cat > ~/.config/gtk-4.0/settings.ini << 'EOF'
[Settings]
gtk-theme-name=catppuccin-mocha-mauve-standard+default
gtk-icon-theme-name=Papirus-Dark
gtk-cursor-theme-name=catppuccin-mocha-dark-cursors
gtk-cursor-theme-size=24
gtk-application-prefer-dark-theme=1
EOF
```

### Cursor en Hyprland

Agregar en `~/.config/hypr/hyprland.lua` junto a las otras variables de entorno:

```lua
hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")
```

### Qt — Kvantum

`hyprland.lua` ya define `QT_STYLE_OVERRIDE=kvantum`. Crear la config de Kvantum con tema oscuro:

```bash
mkdir -p ~/.config/Kvantum
cat > ~/.config/Kvantum/kvantum.kvconfig << 'EOF'
[General]
theme=KvDark
EOF
```

> No existe un tema Kvantum Catppuccin en los repos. `KvDark` es el tema oscuro incluido con Kvantum. Se reemplazará en el Nivel 2 del sistema de temas.

### Validación

Aplicar y abrir apps GTK:

```bash
hyprctl reload
nautilus &
signal-desktop &
```

Salida esperada: fondo oscuro Catppuccin Mocha, iconos Papirus, cursor Catppuccin en todas las apps.

---

## Sistema de temas Omarchy (21 temas)

El sistema replica la experiencia de cambio de temas de Omarchy sin instalar sus repositorios, usando únicamente los assets (colores y wallpapers) del repo público de GitHub.

### Arquitectura

```
~/.config/omarchy/
├── themes/
│   ├── catppuccin/
│   │   └── colors.toml        # colores del tema
│   ├── catppuccin-latte/
│   │   └── colors.toml
│   ├── tokyo-night/
│   │   └── colors.toml
│   └── ...                    # 21 temas en total
└── current/
    ├── theme                  # nombre del tema activo
    ├── alacritty-colors.toml  # generado por theme-apply
    ├── waybar-colors.css      # generado por theme-apply
    ├── hyprland-colors.lua    # generado por theme-apply
    ├── hyprlock-colors.conf   # generado por theme-apply
    └── mako-colors.ini        # generado por theme-apply

~/.local/share/omarchy-local/themed/
├── alacritty-colors.toml.tpl
├── waybar-colors.css.tpl
├── hyprland-colors.lua.tpl
├── hyprlock-colors.conf.tpl
└── mako-colors.ini.tpl

~/.local/share/backgrounds/
└── omarchy-{tema}-{filename}  # wallpapers con prefijo para evitar colisiones

~/.local/bin/
├── theme-apply                # aplica un tema por nombre
└── theme-switcher             # lanza rofi para seleccionar tema
```

### Temas disponibles

| Tema | Paleta |
|---|---|
| `catppuccin` | Catppuccin Mocha (oscuro) |
| `catppuccin-latte` | Catppuccin Latte (claro) |
| `ethereal` | Azules nocturnos |
| `everforest` | Verde bosque |
| `flexoki-light` | Flexoki claro |
| `gruvbox` | Gruvbox retro |
| `hackerman` | Verde neón sobre negro |
| `kanagawa` | Inspirado en la ola de Kanagawa |
| `last-horizon` | Tonos cálidos de horizonte |
| `lumon` | Azul corporativo severo |
| `matte-black` | Negro mate puro |
| `miasma` | Verdes apagados |
| `nord` | Nord ártico |
| `osaka-jade` | Verde jade urbano |
| `retro-82` | Colores años 80 |
| `ristretto` | Marrones cálidos |
| `rose-pine` | Rose Pine |
| `solitude` | Azul noche |
| `tokyo-night` | Tokyo Night |
| `vantablack` | Negro absoluto con acentos mínimos |
| `white` | Blanco puro |

### Estructura de `colors.toml`

Cada tema define los siguientes campos:

```toml
wallpaper = "/home/usuario/.local/share/backgrounds/omarchy-tokyo-night-0-swirl-buck.jpg"

accent = "#7aa2f7"
cursor = "#c0caf5"
foreground = "#a9b1d6"
background = "#1a1b26"
mantle = "#1a1b26"
selection_foreground = "#c0caf5"
selection_background = "#7aa2f7"

color0  = "#32344a"
color1  = "#f7768e"
color2  = "#9ece6a"
color3  = "#e0af68"
color4  = "#7aa2f7"
color5  = "#ad8ee6"
color6  = "#449dab"
color7  = "#787c99"
color8  = "#444b6a"
color9  = "#ff7a93"
color10 = "#b9f27c"
color11 = "#ff9e64"
color12 = "#7da6ff"
color13 = "#bb9af7"
color14 = "#0db9d7"
color15 = "#acb0d0"

# GTK — campos opcionales; si están presentes, theme-apply los aplica via gsettings
gtk_theme    = "catppuccin-mocha-mauve-standard+default"
cursor_theme = "catppuccin-mocha-dark-cursors"
icon_theme   = "Papirus-Dark"
color_scheme = "prefer-dark"
```

El campo `mantle` se usa como fondo de Waybar. Para temas sin él, se asigna igual a `background`.

Los campos GTK son opcionales: si no están presentes, `theme-apply` no modifica el GTK. Si `cursor_theme = ""` (cadena vacía), el cursor no se cambia.

#### Valores GTK por tipo de tema

| Tipo | `gtk_theme` | `cursor_theme` | `icon_theme` | `color_scheme` |
|------|------------|----------------|--------------|----------------|
| catppuccin (dark) | `catppuccin-mocha-mauve-standard+default` | `catppuccin-mocha-dark-cursors` | `Papirus-Dark` | `prefer-dark` |
| catppuccin-latte (light) | `catppuccin-latte-mauve-standard+default` | `catppuccin-latte-dark-cursors` | `Papirus` | `prefer-light` |
| Otros dark (17) | `catppuccin-mocha-mauve-standard+default` | `catppuccin-mocha-dark-cursors` | `Papirus-Dark` | `prefer-dark` |
| Otros light (3: flexoki-light, rose-pine, white) | `Adwaita` | (sin cambio) | `Papirus` | `prefer-light` |

### Script `theme-apply`

Lee `colors.toml` del tema indicado, sustituye variables en los 5 templates y recarga los servicios:

```bash
theme-apply tokyo-night
```

Componentes que recarga:

| Componente | Archivo generado | Recarga |
|---|---|---|
| Alacritty | `current/alacritty-colors.toml` | automática (archivo incluido) |
| Waybar | `current/waybar-colors.css` | `pkill waybar && waybar` — `style.css` lo importa con `@import url(...)` al inicio, por lo que el cambio de tema es totalmente dinámico |
| Hyprland | `current/hyprland-colors.lua` | `hyprctl reload` |
| Hyprlock | `current/hyprlock-colors.conf` | en el próximo bloqueo |
| Mako | `current/mako-colors.ini` + edita `~/.config/mako/config` | `makoctl reload` |
| Wallpaper | campo `wallpaper` de colors.toml | `pkill swaybg && swaybg -i ... -m fill` |
| GTK + cursor + iconos | gsettings + `gtk-{3,4}.0/settings.ini` | inmediata para GTK3/4 |

### Script `theme-switcher`

Lanza rofi para seleccionar un tema de forma interactiva:

```bash
theme-switcher
```

Keybinding: `Super + Shift + T`

### Templates

Los templates usan `{{ variable }}` como marcadores. Ejemplo — `waybar-colors.css.tpl`:

```css
@define-color foreground {{ foreground }};
@define-color background {{ mantle }};
@define-color surface    {{ background }};
@define-color accent     {{ accent }};
@define-color warning    {{ color1 }};
@define-color critical   {{ color1 }};
```

Las variables con sufijo `_strip` (ej. `{{ accent_strip }}`) contienen el color sin el `#`, para usarlas en contextos Hyprland/Hyprlock que requieren el formato `rgba(rrggbbaa)`.

### Instalación

La función `install_theme_switcher()` del script `install-hyprland-desktop.sh` automatiza todo el proceso:

1. Instala `catppuccin-gtk-theme-latte` y `catppuccin-cursors-latte` (necesarios para el tema latte)
2. Crea la estructura de directorios
3. Instala los 6 templates en `~/.local/share/omarchy-local/themed/` (alacritty, waybar, hyprland, hyprlock, mako y **rofi**)
4. Instala `theme-apply` y `theme-switcher` en `~/.local/bin/`
5. Clona el repo de Omarchy con sparse-checkout para obtener wallpapers y `colors.toml`
6. Copia los wallpapers a `~/.local/share/backgrounds/` con prefijo `omarchy-{tema}-`
7. Genera el `colors.toml` de cada tema: detecta dark/light por luminancia del `background` y asigna los campos GTK correspondientes
8. Agrega el binding `Super+Shift+T` a `hyprland.lua`
9. Aplica el tema `nord` por defecto (genera `waybar-colors.css`, `rofi.rasi` y archivos de tema en `current/`)

> El paso 9 se ejecuta siempre, incluso sin sesión Wayland activa. Esto garantiza que `waybar-colors.css` exista antes del primer login — sin él, Waybar falla al arrancar.

> [!CAUTION]
> **Requisito de PATH:** el bind `Super+Shift+T` ejecuta `theme-switcher` (un script en `~/.local/bin/`). La sesión gráfica de `uwsm` arranca con un PATH mínimo que **no incluye `~/.local/bin`**, así que el bind fallaría con "command not found" silencioso. La función `init_hyprland_config()` resuelve esto creando `~/.config/uwsm/env` con:
> ```sh
> export PATH="$HOME/.local/bin:$PATH"
> ```
> `uwsm` sourcea ese archivo al iniciar sesión. **Requiere reiniciar la sesión** de Hyprland (logout/login) para que el PATH aplique.

```bash
bash install-hyprland-desktop.sh
```

O solo la función de temas si el resto ya está instalado:

```bash
source install-hyprland-desktop.sh && install_theme_switcher
```

### Añadir o modificar un tema

Para añadir un tema nuevo:

```bash
mkdir -p ~/.config/omarchy/themes/mi-tema
vim ~/.config/omarchy/themes/mi-tema/colors.toml
theme-apply mi-tema
```

Para sobrescribir el wallpaper de un tema sin editar `colors.toml`:

```bash
sed -i 's|^wallpaper = .*|wallpaper = "/ruta/al/fondo.jpg"|' \
    ~/.config/omarchy/themes/nord/colors.toml
theme-apply nord
```

---

## Capturas de pantalla: grim + slurp + satty

### Por qué no Shutter ni Flameshot

**Shutter** es la herramienta de referencia en X11: captura integrada con editor de anotaciones
completo (flechas, recuadros, texto, blur). En Wayland no funciona porque depende de la
API de captura de X11.

**Flameshot** tiene soporte experimental para Wayland pero presenta problemas recurrentes:
el cursor no aparece en la captura, no detecta correctamente el monitor en configuraciones
multi-pantalla, y la ventana de edición puede quedar detrás del compositor.

La solución Wayland-native que usa Omarchy es la combinación de tres herramientas:

| Herramienta | Rol | Equivalente en Shutter |
|---|---|---|
| `grim` | Captura la pantalla o región a un PNG | Motor de captura interno de Shutter |
| `slurp` | Selector visual de área/ventana con cursor crosshair | Selector de región de Shutter |
| `satty` | Editor de anotaciones GTK4: flechas, recuadros, texto, blur | Editor integrado de Shutter |

### Modos de captura

Cuatro scripts wrapper en `~/.local/bin/` cubren los casos de uso habituales:

| Script | Keybinding | Qué hace |
|---|---|---|
| `screenshot-area` | `Print` | Selección de área con crosshair → abre satty para anotar |
| `screenshot-full` | `Super+Print` | Pantalla completa → abre satty para anotar |
| `screenshot-window` | `Super+Shift+Print` | Ventana activa (vía `hyprctl`) → abre satty para anotar |
| `screenshot-copy` | `Ctrl+Print` | Selección de área → copia PNG directo al portapapeles, sin satty |

Todas las capturas se guardan en `~/Pictures/Screenshots/` con nombre `YYYYMMDD_HHMMSS.png`.

### Flujo de trabajo con satty

El flujo es equivalente a Shutter: seleccionas el área, se abre satty con la imagen,
anotas, y guardas.

```
Print  (selección de área)
  └─ slurp         ← cursor crosshair, selecciona área con click y arrastre
       └─ grim -g  ← captura la región seleccionada a stdout
            └─ satty --filename -   ← abre editor con la imagen
                    ├─ Ctrl+S       → guarda en ~/Pictures/Screenshots/
                    ├─ Ctrl+C       → copia al portapapeles
                    └─ Esc          → descarta sin guardar

Super+Print  (pantalla completa)
  └─ grim -        ← captura toda la pantalla a stdout
       └─ satty --filename -   ← abre editor con la imagen
```

### Herramientas de anotación en satty

| Herramienta | Combinación | Descripción |
|---|---|---|
| Flecha | `A` | Flecha direccional con punta |
| Rectángulo | `R` | Recuadro vacío o relleno |
| Línea | `L` | Línea recta |
| Texto | `T` | Texto con fuente configurable |
| Resaltado | `H` | Rectángulo semitransparente |
| Blur | `B` | Difuminado gaussiano de área |
| Pixelado | `P` | Pixelado de área (censurar datos) |
| Recorte | `C` | Recorta la imagen al área seleccionada |
| Deshacer | `Ctrl+Z` | Deshace la última anotación |
| Rehacer | `Ctrl+Shift+Z` | Rehace la última anotación deshecha |

### Instalación

El script `install-hyprland-desktop.sh` instala los paquetes, crea los cuatro scripts
wrapper y configura los keybindings:

```bash
bash install-hyprland-desktop.sh
```

Para instalación manual:

```bash
paru -S --needed grim slurp satty jq
mkdir -p ~/Pictures/Screenshots ~/.local/bin
```

Luego copiar los scripts `screenshot-area`, `screenshot-full`, `screenshot-window` y
`screenshot-copy` a `~/.local/bin/` y darles permiso de ejecución.

### Captura desde la línea de comandos

```bash
# Área seleccionada, guardar en archivo
grim -g "$(slurp)" ~/Pictures/Screenshots/captura.png

# Pantalla completa al portapapeles
grim - | wl-copy

# Ventana activa
grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" captura.png

# Área seleccionada, abrir en satty con guardado en ruta específica
grim -g "$(slurp)" - | satty --filename - --output-filename ~/captura.png
```

---

## Grabación de pantalla: GPU Screen Recorder

**GPU Screen Recorder** usa la GPU para codificar el video (VAAPI en Intel Iris Xe), a diferencia de wf-recorder que codifica por software en CPU. El resultado es menor consumo de recursos, mayor framerate sostenido y archivos de mejor calidad.

Se instala en tres componentes:

| Paquete | Rol |
|---|---|
| `gpu-screen-recorder` | Motor de grabación — CLI que accede a la GPU vía VAAPI |
| `gpu-screen-recorder-ui` | Overlay fullscreen estilo ShadowPlay — configura y controla la grabación |
| `gpu-screen-recorder-notification` | Notificaciones OSD al iniciar/detener grabación |

### Uso

El UI (`gsr-ui`) corre como daemon en segundo plano desde el autostart. Se activa con `Alt+Z` o con `Super+Ctrl+R` desde Hyprland.

El overlay permite:
- Seleccionar la fuente (pantalla completa, ventana específica)
- Elegir la fuente de audio (micrófono, audio del escritorio, ambos, ninguno)
- Activar el replay buffer (guarda los últimos N minutos retroactivamente)
- Iniciar/detener la grabación
- Iniciar/detener streaming

Los archivos se guardan en `~/Videos/`.

### Autostart

```lua
hl.exec_cmd("uwsm app -- gsr-ui launch-daemon")
```

`launch-daemon` inicia el proceso en segundo plano sin abrir el overlay. `Alt+Z` o `Super+Ctrl+R` lo muestran cuando se necesita.

### Verificación

```bash
paru -Q gpu-screen-recorder gpu-screen-recorder-ui gpu-screen-recorder-notification
```

Abrir desde rofi → "GPU Screen Recorder" o presionar `Super+Ctrl+R`. El overlay aparece en pantalla completa.

---

## Pomodoro

El script `pomodoro` implementa la técnica Pomodoro usando bash puro. Usa `rofi` para el menú interactivo y `mako` para las notificaciones — sin paquetes adicionales. Se lanza con `Super+Ctrl+P`.

El script queda instalado en `~/.local/bin/pomodoro` y aparece en rofi como entrada de aplicaciones.

### Comandos

| Comando | Acción |
|---|---|
| `pomodoro` | Abre el menú rofi (equivalente a `menu`) |
| `pomodoro start [mins]` | Inicia sesión — 25 min por defecto |
| `pomodoro stop` | Cancela la sesión activa |
| `pomodoro status` | Muestra el tiempo restante (`MM:SS restante`) |

### Menú rofi

```
Iniciar 25 min
Iniciar 50 min
Descanso 5 min
Cancelar sesion
Estado: 14:32 restante
```

La última línea refleja el estado en tiempo real. Al completarse la sesión, `mako` envía una notificación de urgencia normal.

### Keybinding

```lua
hl.bind(mainMod .. " + CTRL + P", hl.dsp.exec_cmd("~/.local/bin/pomodoro"))
```

---

<<<<<<< HEAD
## Referencia de keybindings (show-keys)

El script `show-keys` muestra la lista completa de atajos del escritorio en un panel rofi de solo lectura. Se lanza con `Super + /`.
=======
## Referencia de combinaciones de teclas (show-keys)

El script `show-keys` muestra la lista completa de combinaciones de teclas del escritorio en un panel rofi de solo lectura. Se lanza con `Super + /`.
>>>>>>> origin/main

El script queda instalado en `~/.local/bin/show-keys`.

### Comportamiento

- Abre rofi en modo `dmenu` con el flag `--no-custom`: el panel es solo de consulta, no ejecuta ninguna acción al seleccionar una línea.
- Usa el tema `catppuccin-mocha.rasi` si está disponible; de lo contrario usa el tema por defecto de rofi.
- El panel ocupa el 55 % del ancho de pantalla.
<<<<<<< HEAD
- Los atajos están agrupados por categoría: aplicaciones, ventanas, foco, workspaces, sesión, notificaciones y capturas.

### Keybinding
=======
- Las combinaciones de teclas están agrupadas por categoría: aplicaciones, ventanas, foco, workspaces, sesión, notificaciones y capturas.

### Combinación de teclas
>>>>>>> origin/main

```lua
hl.bind(mainMod .. " + /", hl.dsp.exec_cmd("~/.local/bin/show-keys"))
```

<<<<<<< HEAD
> Para la referencia completa de atajos documentada en el manual, ver el [Capítulo 14 — Uso de Hyprland](Capítulo-14-Uso-Hyprland.md).
=======
> Para la referencia completa de combinaciones de teclas documentada en el manual, ver el [Capítulo 14 — Uso de Hyprland](Capítulo-14-Uso-Hyprland.md).
>>>>>>> origin/main

---

## DNS local: systemd-resolved + avahi

### Arquitectura

El sistema de resolución de nombres queda en dos capas:

```
Aplicación
    │
    ▼
NSS (nsswitch.conf)
    ├─ mdns_minimal → avahi-daemon   ← resuelve *.local via mDNS (red local)
    └─ resolve      → systemd-resolved (127.0.0.53)
                         ├─ cache local    ← responde sin ir a la red si ya consultó
                         └─ upstream DNS   ← el que asigne NetworkManager (router/ISP)
```

| Componente | Paquete | Función |
|---|---|---|
| `systemd-resolved` | (preinstalado) | Cache DNS local, stub en `127.0.0.53` |
| `avahi-daemon` | `avahi` | Daemon mDNS — anuncia y resuelve nombres `.local` |
| `nss-mdns` | `nss-mdns` | Plugin NSS que conecta avahi con el sistema de resolución |

### Qué resuelve cada capa

| Consulta | Quién responde | Ejemplo |
|---|---|---|
| `hostname.local` | avahi (mDNS multicast) | `laptop.local` → `IP` |
| Dominio externo (caché) | systemd-resolved (memoria) | Segunda consulta a `archlinux.org` |
| Dominio externo (nuevo) | DNS upstream vía systemd-resolved | Primera consulta a cualquier dominio |

### Configuración aplicada

**`/etc/NetworkManager/conf.d/dns.conf`** — NM delega DNS a systemd-resolved:

```ini
[main]
dns=systemd-resolved
```

**`/etc/resolv.conf`** — symlink al stub de systemd-resolved:

```
nameserver 127.0.0.53
options edns0 trust-ad
```

**`/etc/nsswitch.conf`** — orden de resolución de nombres:

```
hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns
```

`mdns_minimal` intercepta solo las consultas `.local` y las pasa a avahi. El resto sigue a `resolve` (systemd-resolved). El flag `[NOTFOUND=return]` evita que consultas `.local` fallen hacia DNS público.

### Verificación

```bash
# Confirmar que avahi resuelve el nombre local
avahi-resolve --name laptop.local

# Confirmar cache DNS (segunda consulta debe decir "Data from: cache")
resolvectl query archlinux.org
resolvectl query archlinux.org

# Ver estado general
resolvectl status
```

### Instalación

```bash
paru -S --needed avahi nss-mdns

# Integrar NetworkManager con systemd-resolved
printf '[main]\ndns=systemd-resolved\n' | sudo tee /etc/NetworkManager/conf.d/dns.conf

# Habilitar servicios
sudo systemctl enable --now systemd-resolved avahi-daemon

# Enlazar resolv.conf al stub
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# Añadir mdns_minimal a la resolución de nombres
sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' /etc/nsswitch.conf

# Aplicar configuración de NM
sudo systemctl restart NetworkManager
```

---

## Firewall: ufw

CachyOS no activa firewall por defecto. `ufw` (Uncomplicated Firewall) es la capa más sencilla sobre iptables/nftables: reglas declarativas, sin archivos de configuración complejos.

### Arquitectura

```
Tráfico entrante
       |
  [ ufw / iptables ]
       |
  +----+---------------------+
  |    |                     |
 SSH  mDNS           traceroute UDP
(22)  (5353/udp)    (33434-33524/udp)
       |
  [DENY el resto]

Tráfico saliente  →  ALLOW ALL (sin restricción)
```

### Reglas configuradas

| Regla | Puerto/Proto | Motivo |
|---|---|---|
| default deny incoming | — | Rechaza todo lo no explícito |
| default allow outgoing | — | Navegación, actualizaciones, SSH saliente |
| allow ssh | 22/tcp | Acceso remoto al laptop desde la red local |
| allow mDNS avahi | 5353/udp | Resolución `.local` (avahi-daemon) |
| allow traceroute | 33434:33524/udp | Sondas de traceroute entrantes |

> Las respuestas ICMP `time-exceeded` (necesarias para que traceroute funcione) las permite `before.rules` de ufw por defecto — no requieren regla adicional.

### Instalación

```bash
paru -S --needed ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh comment 'SSH'
sudo ufw allow 5353/udp comment 'mDNS avahi'
sudo ufw allow in proto udp to any port 33434:33524 comment 'traceroute'
sudo ufw --force enable
sudo systemctl enable ufw
```

### Verificación

```bash
sudo ufw status verbose
```

```
Status: active
Default: deny (incoming), allow (outgoing), disabled (routed)

To                         Action      From
--                         ------      ----
22                         ALLOW IN    Anywhere
5353/udp                   ALLOW IN    Anywhere    # mDNS avahi
33434:33524/udp            ALLOW IN    Anywhere    # traceroute
```

---

## Almacén de credenciales: gnome-keyring

### ¿Qué es gnome-keyring?

**gnome-keyring** es el almacén seguro de credenciales del sistema. Guarda y protege:

| Tipo de credencial | Ejemplo |
|---|---|
| Contraseñas de sitios web | Firefox, Chrome, Brave |
| Tokens de aplicaciones | Signal, Telegram, apps GNOME |
| Claves WiFi | Redes guardadas vía NetworkManager |
| Claves SSH | Funciona como agente SSH |
| Certificados PKCS11 | Certificados digitales |

Sin gnome-keyring activo, cada vez que se reinicia la sesión las aplicaciones pierden sus credenciales almacenadas y vuelven a pedirlas.

### Auto-desbloqueo con SDDM

CachyOS incluye la integración PAM preconfigurada en `/etc/pam.d/sddm`:

```
auth     optional pam_gnome_keyring.so
session  optional pam_gnome_keyring.so auto_start
```

Esto garantiza que el keyring se desbloquee automáticamente cuando el usuario introduce su contraseña en SDDM. No aparece ningún diálogo extra — el desbloqueo es transparente.

**Requisito importante**: la contraseña del keyring debe coincidir con la contraseña del usuario. Si en algún momento se cambia la contraseña del sistema sin actualizar el keyring, habrá que recrearlo eliminando `~/.local/share/keyrings/`.

### Variable de entorno GNOME_KEYRING_CONTROL

Para que las aplicaciones puedan localizar el socket de control del keyring, se configura la variable en `~/.config/environment.d/gnome-keyring.conf`. systemd lee este archivo antes de arrancar la sesión de usuario, por lo que la variable queda disponible para todas las apps lanzadas desde Hyprland:

```bash
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/gnome-keyring.conf << 'EOF'
GNOME_KEYRING_CONTROL=${XDG_RUNTIME_DIR}/keyring
EOF
```

### Agente SSH

El agente SSH lo provee **gpg-agent** (activo por defecto en CachyOS), que expone su socket en `$XDG_RUNTIME_DIR/gnupg/S.gpg-agent.ssh`. gnome-keyring gestiona el almacén de secretos (contraseñas de aplicaciones, tokens, claves WiFi) y gpg-agent gestiona las claves SSH — sin conflicto.

### Verificación

```bash
pgrep -a gnome-keyring-daemon
```

```
907 /usr/bin/gnome-keyring-daemon --foreground --components=pkcs11,secrets,ssh --control-directory=/run/user/1000/keyring
```

El daemon lo arranca PAM automáticamente al iniciar sesión en SDDM — no se requiere autostart en Hyprland.

```bash
ls /run/user/1000/keyring/
```

```
control  pkcs11
```

---

## Automontaje de dispositivos: udiskie

**udiskie** monitorea el sistema en segundo plano y monta automáticamente cualquier dispositivo de almacenamiento al conectarlo — USB, discos externos, tarjetas SD — sin necesidad de intervención manual.

### Funcionalidades

| Función | Descripción |
|---|---|
| Automontaje | Al conectar el dispositivo, se monta y aparece en Nautilus |
| Ícono en bandeja | Muestra los dispositivos montados y permite expulsarlos de forma segura |
| Expulsión segura | Clic derecho en el ícono → desmontar de forma segura antes de desconectar |
| Notificación | Avisa via mako cuando se monta o desmonta un dispositivo |

### Autostart

```lua
hl.exec_cmd("uwsm app -- udiskie --tray")
```

La opción `--tray` activa el ícono en la bandeja del sistema junto a nm-applet y blueman-applet.

### Verificación

Conectar un USB — debe aparecer automáticamente en Nautilus (panel izquierdo) y en el ícono de bandeja. Para desconectarlo de forma segura: clic derecho en el ícono de udiskie → Unmount.

---

## XDG Desktop Portal

### ¿Qué es xdg-desktop-portal?

**XDG Desktop Portal** es la capa de integración que permite que aplicaciones en sandbox (Flatpak, snap, y también apps nativas) accedan a recursos del sistema de forma segura y con permiso del usuario:

| Función | Descripción |
|---|---|
| Captura de pantalla / grabación | `grim`, obs-studio, navegadores |
| Selector de archivos | Diálogo "Abrir archivo" en apps web y Electron |
| Compartir pantalla | Videoconferencias (Meet, Teams, Discord) |
| Portapapeles y drag & drop | Integración entre apps en Wayland |
| Notificaciones e inhibición de pantalla | Gestión de idle/bloqueo |

Sin el portal activo, las aplicaciones fallan silenciosamente al intentar compartir pantalla o abrir diálogos de archivo nativos.

### Componentes instalados

| Paquete | Función |
|---|---|
| `xdg-desktop-portal` | Demonio base — coordina las solicitudes de portal |
| `xdg-desktop-portal-hyprland` | Implementación específica para Hyprland (screencopy, toplevel) |
| `xdg-desktop-portal-gtk` | Fallback para apps GTK — diálogos de archivo, apariencia |

### Activación automática

En CachyOS con UWSM, los portales se activan automáticamente como servicios systemd del usuario mediante **D-Bus socket activation** — no requieren entrada en autostart de `hyprland.lua`.

Lo que sí es crítico es que Hyprland exporte sus variables al entorno D-Bus del usuario al arrancar:

```lua
hl.exec_cmd("systemctl --user import-environment $(env | cut -d'=' -f 1)")
hl.exec_cmd("dbus-update-activation-environment --systemd --all")
```

Estas líneas garantizan que `WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP=Hyprland` y `HYPRLAND_INSTANCE_SIGNATURE` lleguen al demonio D-Bus, permitiendo que `xdg-desktop-portal-hyprland` detecte correctamente la sesión.

### Verificación

```bash
systemctl --user status xdg-desktop-portal-hyprland.service
```

La salida debe mostrar `active (running)` e incluir líneas como:

```
Got interface: zwlr_screencopy_manager_v1
[screencopy] init successful
```

Para verificar que el selector de archivos funciona, abrir cualquier app web (Firefox, Chromium) y usar "Subir archivo" — debe aparecer el diálogo nativo del sistema en lugar del diálogo interno del navegador.

---

## Agente de autenticación: polkit-gnome

### ¿Qué es polkit?

**Polkit** (antes PolicyKit) es el sistema de autorización de Linux que permite que aplicaciones sin privilegios soliciten operaciones que normalmente requieren root. Define qué puede hacer un usuario regular y bajo qué condiciones.

Sin un agente de autenticación corriendo, las aplicaciones GUI que necesitan privilegios fallan silenciosamente — sin mensaje de error, sin diálogo, simplemente no hacen nada.

**polkit-gnome** es el agente visual para entornos GTK/GNOME. Cuando una aplicación solicita privilegios elevados, polkit-gnome intercepta esa solicitud y muestra un diálogo gráfico pidiendo la contraseña.

### ¿Contraseña de root o del usuario?

Depende de la operación y las reglas de polkit instaladas. En CachyOS con el grupo `wheel`:

| Operación | Contraseña requerida |
|---|---|
| Editar conexiones de red (nmtui, blueman) | Del usuario (wheel) |
| Montar discos via Nautilus admin:// | Del usuario (wheel) |
| `pkexec ls /root` (regla sin excepción) | De root |
| Instalar paquetes desde GUI | Del usuario (wheel) |

La regla general: operaciones de escritorio comunes aceptan la contraseña del propio usuario. `pkexec` genérico sin regla específica pide root.

### Autostart

polkit-gnome debe arrancar con la sesión gráfica. Está configurado en `hyprland.lua`:

```lua
hl.exec_cmd("uwsm app -- /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
```

### Verificación

Desde una terminal en Hyprland, abre Nautilus y navega a:

```
admin:///etc/
```

Debe aparecer un diálogo gráfico pidiendo tu contraseña de usuario. Si acepta → polkit-gnome funciona correctamente.

### SUID en polkit-agent-helper-1

En CachyOS, `polkit-agent-helper-1` puede carecer del bit SUID. Sin él, el agente no puede leer `/etc/shadow` para verificar la contraseña del usuario, lo que resulta en el error `Authentication token manipulation error` aunque la regla polkit sea correcta.

```bash
sudo chmod 4755 /usr/lib/polkit-1/polkit-agent-helper-1
```

Verificar:

```bash
ls -la /usr/lib/polkit-1/polkit-agent-helper-1
# debe mostrar: -rwsr-xr-x
```

### Apps GUI elevadas en Wayland

Las aplicaciones que usan `pkexec` para relanzarse como root (como Raspberry Pi Imager) fallan en Wayland porque `pkexec` no preserva las variables de entorno del usuario. El proceso root arranca sin `WAYLAND_DISPLAY` ni `XDG_RUNTIME_DIR`, y no puede conectar al socket Wayland.

Además, los lectores de tarjetas internos (microSD integrada en el laptop) son clasificados por udisks2 como `HintSystem=true`, lo que hace que la acción de montaje sea `org.freedesktop.udisks2.filesystem-mount-system` — requiere autenticación de administrador por defecto. La regla polkit con `YES` para el grupo `sudo` resuelve esto sin pedir contraseña.

**Regla polkit udisks2** — montaje sin contraseña para usuarios del grupo `sudo`:

```javascript
// /etc/polkit-1/rules.d/50-udisks2.rules
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.udisks2") === 0 &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
```

**Solución para RPi Imager: sudo con env_keep en sudoers**

`pkexec env WAYLAND_DISPLAY=...` ejecuta `/usr/bin/env` como root, lo que dispara `org.freedesktop.policykit.exec` (auth admin por defecto) en lugar de la acción propia de rpi-imager. La solución correcta es usar `sudo` con una regla específica en `/etc/sudoers.d/` que preserve solo las variables de Wayland necesarias:

```
# /etc/sudoers.d/rpi-imager
Defaults!/usr/bin/rpi-imager env_keep += "WAYLAND_DISPLAY XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS"
usuario ALL=(root) NOPASSWD: /usr/bin/rpi-imager
```

El wrapper queda simple:

```bash
# ~/.local/bin/rpi-imager-wayland
#!/usr/bin/env bash
exec sudo /usr/bin/rpi-imager
```

`sudo` lanza rpi-imager directamente como root con las variables Wayland preservadas. Al detectar que ya corre como root, rpi-imager no intenta llamar `pkexec` de nuevo.

Se sobreescribe el `.desktop` en `~/.local/share/applications/` para que rofi use el wrapper:

```ini
# ~/.local/share/applications/com.raspberrypi.rpi-imager.desktop
[Desktop Entry]
Type=Application
Name=Raspberry Pi Imager
Icon=rpi-imager
Exec=~/.local/bin/rpi-imager-wayland %u
Categories=Utility;
```

Con esto, RPi Imager abre desde rofi sin pedir contraseña y con acceso completo al entorno Wayland.

---

## Optimización de batería: TLP

**TLP** es un servicio de gestión de energía para Linux que aplica automáticamente configuraciones óptimas según la fuente de alimentación — corriente alterna (AC) o batería (BAT). Sin TLP, el kernel usa un perfil genérico que no maximiza la duración de la batería.

### ¿Qué hace TLP?

| Función | Descripción |
|---|---|
| Perfil automático | Cambia entre perfil performance (AC) y powersave (BAT) al conectar/desconectar |
| CPU scaling | Ajusta el gobernador de CPU y los límites de frecuencia según el perfil |
| Gestión de discos | Reduce la actividad del disco en batería (APM, spindown) |
| USB autosuspend | Suspende automáticamente dispositivos USB inactivos en batería |
| PCIe ASPM | Activa el ahorro de energía en buses PCIe |

### Instalación

```bash
paru -S tlp
sudo systemctl enable --now tlp
```

### Verificación

```bash
sudo tlp-stat -s
```

Salida esperada (cuando opera con batería):

```
+++ TLP Status
tlp            = enabled, last run: HH:MM:SS
TLP profile    = powersave/BAT
Power source   = BAT
```

TLP no requiere configuración adicional — los valores por defecto son correctos para la mayoría de laptops. Si se necesita ajuste fino (thresholds de carga de batería, etc.), el archivo de configuración está en `/etc/tlp.conf`.

---

## Impresión: CUPS

**CUPS** (Common Unix Printing System) es el subsistema de impresión estándar en Linux. Gestiona colas de impresión, controladores y comunicación con impresoras locales y de red.

### Paquetes instalados

| Paquete | Función |
|---|---|
| `cups` | Servidor de impresión principal |
| `cups-browsed` | Descubrimiento automático de impresoras en la red local |
| `cups-filters` | Filtros de conversión de formato (PDF, PostScript, etc.) |
| `cups-pdf` | Impresora virtual que genera PDF en `~/PDF/` |
| `system-config-printer` | Interfaz gráfica GTK para añadir y gestionar impresoras |

### Instalación

```bash
paru -S cups cups-browsed cups-filters cups-pdf system-config-printer
sudo systemctl enable --now cups
sudo systemctl enable --now cups-browsed
sudo usermod -aG lp $USER
```

El usuario debe pertenecer al grupo `lp` para gestionar impresoras sin privilegios de administrador. El cambio de grupo tiene efecto en la siguiente sesión de login.

### Verificación

```bash
systemctl is-active cups
systemctl is-active cups-browsed
groups $USER | grep lp
```

### Añadir una impresora

Abrir `system-config-printer` desde rofi o desde la terminal. La interfaz detecta automáticamente las impresoras de red disponibles gracias a `cups-browsed`.

La interfaz web de CUPS también está disponible en `http://localhost:631` para configuración avanzada.

---

## Resumen de exclusiones

| Paquete | Motivo |
|---|---|
| `omarchy-walker` | Requiere repo externo de Omarchy — riesgo de conflictos con CachyOS |
| `omarchy-nvim` | Requiere repo externo de Omarchy |
| `aether` | Requiere repo externo de Omarchy — funcionalidad desconocida |
| `tobi-try` | Requiere repo externo de Omarchy — funcionalidad desconocida |
| `iwd` | CachyOS usa NetworkManager con wpa_supplicant — no se modifica |
| `chromium` | Cubierto por Firefox, Chrome, Brave u Opera según preferencia |
| `fcitx5` y módulos | Solo necesario para métodos de entrada de idiomas asiáticos |
| `greetd` / `greetd-agreety` | Reemplazado por SDDM — mejor soporte gráfico y compatibilidad con temas |

---

← [Cap. 11 — Rollback](Capítulo-11-Rollback.md) · [Índice](..) · [Cap. 13 — Configuración Waybar](Capítulo-13-Configuracion-Waybar.md) →
