← [Cap. 13 — Configuración Waybar](Capítulo-13-Configuracion-Waybar.md) · [Índice](..) · [Cap. 15 — Gestión de paquetes](Capítulo-15-Gestion-Paquetes.md) →

---

## Introducción

Este capítulo documenta las combinaciones de teclas configuradas en `~/.config/hypr/hyprland.lua` para la instalación CachyOS + Hyprland descrita en los capítulos anteriores.

La tecla modificadora principal es **Super** (tecla Windows). Los bindings siguen el esquema de Omarchy.

---

## Aplicaciones

| Combinación | Acción |
|---|---|
| `Super + Q` | Abrir terminal (`alacritty`) |
| `Super + E` | Abrir gestor de archivos (`nautilus`) |
| `Super + Space` | Abrir lanzador de apps (`rofi`) |
| `Super + Ctrl + A` | Mezclador de audio (`wiremix` en terminal) |
| `Super + Ctrl + V` | Historial de portapapeles (`cliphist` + `rofi`) |
| `Super + Ctrl + B` | Bluetooth (`blueman-manager`) |
| `Super + Ctrl + W` | WiFi (`nmtui` en terminal) |
| `Super + Ctrl + T` | Monitor de actividad (`btop` en terminal) |
| `Super + Ctrl + P` | Pomodoro (`pomodoro` + rofi) |
| `Super + Shift + T` | Selector de tema Omarchy (`theme-switcher` + rofi) |
| `Super + Ctrl + R` | Grabación de pantalla (`gsr-ui` — GPU Screen Recorder) |
| `Super + /` | Referencia de combinaciones de teclas (`show-keys` + rofi) |

> El ícono `󰣇` de waybar también abre rofi con clic izquierdo, y `alacritty` con clic derecho.

> [!NOTE]
> **`Super + /` — Referencia de combinaciones de teclas (`show-keys`)**
> Ejecuta el script `~/.local/bin/show-keys`, que abre un panel rofi de solo lectura (flag `--no-custom`) con la lista completa de combinaciones de teclas organizada por categoría: aplicaciones, ventanas, foco, workspaces, sesión, notificaciones y capturas. El panel ocupa el 55 % del ancho de pantalla y usa el tema catppuccin-mocha si está disponible. Es de consulta rápida: no ejecuta nada, solo muestra.

---

## Gestión de ventanas

| Combinación | Acción |
|---|---|
| `Super + Shift + W` | Cerrar ventana activa |
| `Super + T` | Alternar modo flotante / tiling |
| `Super + F` | Pantalla completa |
| `Super + Alt + F` | Maximizar (fullscreen en modo tiling) |
| `Super + P` | Alternar modo pseudo-tile |
| `Super + J` | Alternar dirección del split (horizontal ↔ vertical) |
| `Super + G` | Agrupar / desagrupar ventanas |
| `Super + Shift + Space` | Mostrar / ocultar waybar |
| `Super + Shift + ←` | Mover ventana a la mitad izquierda de la pantalla |
| `Super + Shift + →` | Mover ventana a la mitad derecha de la pantalla |
| `Super + Shift + ↑` | Mover ventana a la mitad superior de la pantalla |
| `Super + Shift + ↓` | Mover ventana a la mitad inferior de la pantalla |
| `Super + Shift + Y` | Ciclar tamaño de ventana (50% alto ↔ 50% ancho ↔ 100% maximizado ↔ mosaico) |

### Mover y redimensionar con el ratón

| Combinación | Acción |
|---|---|
| `Super + Clic izquierdo` + arrastrar | Mover ventana |
| `Super + Clic derecho` + arrastrar | Redimensionar ventana |

---

## Foco entre ventanas

| Combinación | Acción |
|---|---|
| `Super + ←` | Enfocar ventana a la izquierda |
| `Super + →` | Enfocar ventana a la derecha |
| `Super + ↑` | Enfocar ventana arriba |
| `Super + ↓` | Enfocar ventana abajo |
| `Alt + Tab` | Siguiente ventana |
| `Alt + Shift + Tab` | Ventana anterior |

### Navegación dentro de grupos

| Combinación | Acción |
|---|---|
| `Super + Alt + Tab` | Siguiente ventana en el grupo activo |
| `Super + Alt + Shift + Tab` | Ventana anterior en el grupo activo |

---

## Workspaces

### Cambiar de workspace

| Combinación | Acción |
|---|---|
| `Super + 1` … `Super + 9` | Ir al workspace 1–9 |
| `Super + 0` | Ir al workspace 10 |
| `Super + Tab` | Ir al workspace siguiente |
| `Super + Shift + Tab` | Ir al workspace anterior |
| `Super + Ctrl + Tab` | Volver al workspace usado anteriormente |
| `Super + Scroll ↓` | Ir al workspace siguiente |
| `Super + Scroll ↑` | Ir al workspace anterior |

### Mover ventana a otro workspace

| Combinación | Acción |
|---|---|
| `Super + Shift + 1` … `Super + Shift + 9` | Mover ventana al workspace 1–9 |
| `Super + Shift + 0` | Mover ventana al workspace 10 |

### Workspace especial (scratchpad)

| Combinación | Acción |
|---|---|
| `Super + S` | Mostrar/ocultar workspace especial (`magic`) |
| `Super + Shift + S` | Mover ventana al workspace especial |

> El workspace especial es un scratchpad: las ventanas ahí quedan ocultas y se recuperan con `Super + S`.

---

## Sesión

| Combinación | Acción |
|---|---|
| `Super + Ctrl + L` | Bloquear pantalla (`hyprlock`) |
| `Super + Ctrl + L` | Bloquear pantalla (`hyprlock`) |
| `Super + M` | Menú visual de sesión — presenta opciones de apagar, reiniciar, suspender, salir y bloquear (`hypr-exit`) |
| `Super + Space` → «Pantalla y energía» | Ajustar tiempos de bloqueo, suspensión e hibernación (`idle-settings`) |

> [!NOTE]
> `Super + M` ejecuta el script `~/.local/bin/hypr-exit`, que abre un menú Rofi con el tema activo para elegir entre:
> - **Cancelar**: No hace nada y vuelve al escritorio (por defecto).
> - **Bloquear**: Bloquea la pantalla inmediatamente usando `hyprlock`.
> - **Suspender**: Coloca la laptop/desktop en estado de suspensión (`systemctl suspend`).
> - **Salir**: Finaliza de forma segura la sesión gráfica (`uwsm stop` o `hyprctl dispatch exit`).
> - **Reiniciar**: Reinicia el equipo (`systemctl reboot`).
> - **Apagar**: Apaga el sistema de forma limpia (`systemctl poweroff`).

> [!NOTE]
> **«Pantalla y energía»** (`idle-settings`) se abre desde el lanzador rofi (`Super + Space`) y permite fijar, en menús consecutivos, los tiempos de inactividad para **bloquear la pantalla**, **suspender** e **hibernar** el equipo. El menú de hibernación solo aparece si el sistema la soporta. Los cambios se aplican en caliente, sin reiniciar la sesión. Ver detalle en el [Capítulo 12](Capítulo-12-Instalacion-Hyprland.md).

---

## Notificaciones

| Combinación | Acción |
|---|---|
| `Super + ,` | Descartar última notificación |
| `Super + Shift + ,` | Descartar todas las notificaciones |

> Las notificaciones las gestiona `mako`. El historial y las notificaciones activas se ven en waybar.

---

## Teclas multimedia

Estas teclas funcionan incluso con la pantalla bloqueada (`locked = true`).

| Tecla | Acción |
|---|---|
| `Vol +` | Subir volumen (OSD visible via swayosd) |
| `Vol -` | Bajar volumen (OSD visible via swayosd) |
| `Mute` | Silenciar/activar audio |
| `Mic Mute` | Silenciar/activar micrófono |
| `Brillo +` | Aumentar brillo de pantalla |
| `Brillo -` | Reducir brillo de pantalla |
| `Media siguiente` | Siguiente pista (`playerctl`) |
| `Media anterior` | Pista anterior (`playerctl`) |
| `Play/Pause` | Reproducir o pausar (`playerctl`) |

---

## Capturas de pantalla

Las herramientas instaladas son **grim** (captura), **slurp** (selección) y **satty** (anotaciones).

| Combinación | Acción |
|---|---|
| `Print` | Captura de área seleccionada → abre en satty para anotar → guarda en `~/Pictures/` |
| `Super + Print` | Captura de pantalla completa → abre en satty → guarda en `~/Pictures/` |
| `Super + Shift + Print` | Captura de ventana activa → abre en satty → guarda en `~/Pictures/` |
| `Ctrl + Print` | Captura de área → copia directamente al portapapeles |

---

## Grabación de pantalla

La herramienta instalada es **GPU Screen Recorder** — overlay estilo ShadowPlay con codificación por GPU (VAAPI).

| Combinación | Acción |
|---|---|
| `Super + Ctrl + R` | Abre el overlay de GPU Screen Recorder |
| `Alt + Z` | Muestra/oculta el overlay (combinación nativa del programa) |

El overlay permite seleccionar fuente de video, fuente de audio y activar el replay buffer. Los videos se guardan en `~/Videos/`.

---

## Referencia rápida

```
── Aplicaciones ─────────────────────────────────────────
Super  +  Q              →  Terminal (alacritty)
Super  +  E              →  Archivos (nautilus)
Super  +  Space          →  Lanzador (rofi)
Super  +  Ctrl + A       →  Audio (wiremix)
Super  +  Ctrl + V       →  Portapapeles (cliphist)
Super  +  Ctrl + B       →  Bluetooth (blueman)
Super  +  Ctrl + W       →  WiFi (nmtui)
Super  +  Ctrl + T       →  Monitor (btop)
Super  +  Ctrl + P       →  Pomodoro
Super  +  Ctrl + R       →  Grabación (GPU Screen Recorder)
Super  +  Shift + T      →  Selector de tema
Super  +  /              →  Referencia de combinaciones de teclas
── Ventanas ─────────────────────────────────────────────
Super  +  Shift + W      →  Cerrar ventana
Super  +  T              →  Flotante / tiling
Super  +  F              →  Pantalla completa
Super  +  Alt + F        →  Maximizar
Super  +  P              →  Pseudo-tile
Super  +  J              →  Cambiar split
Super  +  G              →  Agrupar ventanas
Super  +  Shift + Space  →  Mostrar/ocultar waybar
Super  +  Shift + ←↑↓→  →  Mitad de pantalla (izq/der/arriba/abajo)
Super  +  Shift + Y      →  Ciclar tamaño (50% alto/ancho/100%/mosaico)
── Foco y ciclo ─────────────────────────────────────────
Super  +  ←↑↓→          →  Enfocar ventana
Alt    +  Tab            →  Siguiente ventana
Alt    +  Shift + Tab    →  Ventana anterior
Super  +  Alt + Tab      →  Siguiente en grupo
Super  +  Alt + Shift + Tab  →  Anterior en grupo
── Workspaces ───────────────────────────────────────────
Super  +  1-9 / 0        →  Ir a workspace
Super  +  Shift + 1-9/0  →  Mover ventana a workspace
Super  +  Tab            →  Workspace siguiente
Super  +  Shift + Tab    →  Workspace anterior
Super  +  Ctrl + Tab     →  Workspace anterior (historial)
── Scratchpad ───────────────────────────────────────────
Super  +  S              →  Mostrar/ocultar scratchpad
Super  +  Shift + S      →  Enviar ventana al scratchpad
── Sesión ───────────────────────────────────────────────
Super  +  Ctrl + L       →  Bloquear pantalla
Super  +  M              →  Salir de Hyprland
── Notificaciones ───────────────────────────────────────
Super  +  ,              →  Descartar notificación
Super  +  Shift + ,      →  Descartar todas
── Capturas de pantalla ─────────────────────────────────
Print                        →  Área seleccionada → archivo
Super  +  Print              →  Pantalla completa → archivo
Super  +  Shift + Print      →  Ventana activa → archivo
Ctrl   +  Print              →  Área → portapapeles
```

---

← [Cap. 13 — Configuración Waybar](Capítulo-13-Configuracion-Waybar.md) · [Índice](..) · [Cap. 15 — Gestión de paquetes](Capítulo-15-Gestion-Paquetes.md) →
