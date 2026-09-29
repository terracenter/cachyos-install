# Capítulo 12: Instalación de Hyprland

[← Cap. 11: Rollback](Capítulo-11-Rollback.md) · [Índice](./_index.md) · [Cap. 13: Configuración de Waybar →](Capítulo-13-Configuracion-Waybar.md)

## Objetivo

Este capítulo describe la instalación modular del escritorio Hyprland del proyecto `cachyos-install`. La implementación actual está orientada a CachyOS, Hyprland 0.56 o posterior y una sesión Wayland administrada con UWSM.

La documentación describe el estado implementado por los scripts del repositorio. Si existe una diferencia entre este capítulo y el código, los scripts son la fuente de verdad.

## Requisitos previos

- CachyOS instalado y arrancando correctamente.
- Usuario normal con permisos administrativos por `sudo`.
- Conexión de red funcional.
- Repositorio clonado en el directorio personal.
- Rama deseada actualizada y árbol de trabajo limpio.
- Snapshot o respaldo reciente antes de cambios relevantes.

Comprueba el repositorio:

```bash
cd ~/cachyos-install
git status --short
git branch --show-current
git log -1 --oneline
```

> **Importante:** ejecuta el instalador como usuario normal. Los módulos elevan privilegios únicamente cuando es necesario.

## Punto de entrada

El punto de entrada del proyecto es:

```bash
cd ~/cachyos-install
./install.sh
```

Selecciona la instalación del escritorio Hyprland desde el menú. El flujo principal es:

```text
install.sh
└── hyprland/install-hyprland-desktop.sh
    ├── install/basico/
    └── install/configuracion/
```

Las aplicaciones adicionales se mantienen separadas del escritorio base:

```text
hyprland/install-hyprland-apps.sh
└── hyprland/install/apps/
```

Esta separación permite validar primero una sesión gráfica mínima y funcional antes de añadir aplicaciones de oficina, desarrollo, multimedia, gaming o virtualización.

## Arquitectura modular

### Módulos básicos

Los módulos básicos instalan y generan los componentes esenciales del escritorio:

- Paquetes de Hyprland y utilidades de Wayland.
- Waybar.
- Rofi.
- Alacritty.
- Nautilus.
- Portapapeles con `wl-clipboard` y `cliphist`.
- Dependencias auxiliares como `jq`, `socat`, `libnotify`, `fortune-mod` y `swaybg`.
- Configuración Lua de Hyprland.
- Atajos de teclado.

### Módulos de configuración

Los módulos de configuración se encargan de:

- Audio con PipeWire y WirePlumber.
- Monitores y espacios de trabajo.
- Teclado, mouse y touchpad.
- Apariencia, temas y fondos.
- Hyprlock y pantalla de bloqueo.
- Menú seguro de sesión y energía.
- SDDM.

## Configuración Lua de Hyprland

Desde Hyprland 0.55, la configuración Lua reemplaza progresivamente la sintaxis histórica de Hyprland. Este proyecto usa:

```text
~/.config/hypr/
├── hyprland.lua
└── modules/
    ├── appearance.lua
    ├── autostart.lua
    ├── input.lua
    ├── keybindings.lua
    └── monitors.lua
```

`hyprland.lua` carga los módulos con `require()`:

```lua
require("modules/monitors")
require("modules/input")
require("modules/appearance")
require("modules/autostart")
require("modules/keybindings")
```

La configuración se puede recargar sin cerrar sesión:

```bash
hyprctl reload
hyprctl configerrors
```

La documentación oficial de Hyprland recomienda dividir la configuración Lua mediante `require()` para aislar módulos y facilitar el mantenimiento.

## Sesión y autostart

El módulo de autostart inicia una sola instancia de los componentes necesarios:

- Waybar mediante UWSM.
- Centro de notificaciones.
- `nm-applet`.
- Hypridle.
- Agente gráfico de PolicyKit.
- Historial de portapapeles.
- Monitor dinámico de espacios de trabajo.
- Aplicación del tema activo.

Waybar se inicia únicamente desde el autostart. El script de temas no debe iniciar otra instancia.

## Monitores y espacios de trabajo

El proyecto detecta las salidas disponibles con `hyprctl` y asigna cinco espacios de trabajo por monitor. La asignación se actualiza cuando se conecta o desconecta una pantalla.

Comprueba las salidas:

```bash
hyprctl monitors -j | jq -r '.[].name'
```

Comprueba el proceso auxiliar:

```bash
pgrep -af hypr-monitor-workspaces
```

## Teclado, mouse y touchpad

El instalador ofrece configuraciones de teclado como:

- Latinoamericano.
- Español.
- Inglés de Estados Unidos.
- Inglés internacional con teclas muertas.

Para escribir acentos con un teclado US se usa:

```lua
kb_layout = "us"
kb_variant = "intl"
```

Ejemplos:

```text
' + a = á
' + e = é
~ + n = ñ
```

La configuración también incorpora sensibilidad del puntero y opciones de touchpad. El diálogo solo pregunta por touchpad cuando detecta uno.

## Waybar y Rofi

Waybar muestra espacios de trabajo, reloj, red, audio, CPU, memoria, batería, bandeja y menú de energía. Rofi actúa como lanzador y como interfaz de los menús del proyecto.

Los detalles de Waybar se encuentran en el [Capítulo 13](Capítulo-13-Configuracion-Waybar.md).

## Temas y fondos

Los temas se almacenan en:

```text
~/.config/omarchy/themes/
```

El estado del tema activo se guarda en:

```text
~/.config/omarchy/current/
```

El selector se ejecuta con:

```bash
theme-switcher
```

Al elegir un tema, el sistema:

1. Valida que la paleta tenga los colores obligatorios.
2. Genera los colores de Alacritty y Waybar.
3. Actualiza los bordes de Hyprland.
4. Aplica preferencias GTK cuando estén definidas.
5. Guarda el tema activo.
6. Recarga Hyprland.
7. Reinicia únicamente `swaybg` para aplicar el fondo.

Los temas incompletos no aparecen en el selector. El fondo predeterminado es mantenido por `swaybg`.

Comprueba el tema y el fondo:

```bash
cat ~/.config/omarchy/current/theme
pgrep -af swaybg
```

## Hyprlock

Hyprland usa Lua, pero Hyprlock continúa usando:

```text
~/.config/hypr/hyprlock.conf
```

El instalador genera una pantalla de bloqueo con:

- Hora en formato de 12 horas.
- Fecha `día-mes-año`.
- Campo de contraseña centrado.
- Firma de texto, firma gráfica privada o Fortune.
- Posición y tamaño configurables desde Rofi.

El configurador se abre con:

```bash
~/.local/bin/lockscreen-settings
```

La firma empresarial, si existe, se mantiene fuera del repositorio:

```text
~/.local/share/hyprlock/company-signature.png
```

La ruta está excluida de Git. El instalador continúa normalmente si la imagen privada no existe.

## Menú de energía

`Super + M` y el botón de energía de Waybar abren el mismo menú. Incluye:

- Bloquear.
- Cerrar sesión.
- Suspender.
- Hibernar.
- Reiniciar.
- Apagar.
- Cancelar.

Las acciones críticas requieren confirmación. En equipos de producción deben evitarse cierres de sesión y reinicios salvo que sean imprescindibles.

## SDDM

El módulo de SDDM instala y habilita el display manager, y comprueba que exista una sesión Hyprland válida. No debe mezclarse con la instalación de temas de GRUB o Plymouth.

Comprueba el estado sin reiniciar:

```bash
systemctl is-enabled sddm.service
ls /usr/share/wayland-sessions/
```

## Validación posterior

Antes de cerrar sesión o reiniciar, valida:

```bash
hyprctl reload
hyprctl configerrors
pgrep -af waybar
pgrep -af swaybg
```

Debe existir una sola instancia de Waybar y una sola instancia de `swaybg`.

Prueba también:

```text
Super + Enter              Alacritty
Super + E                  Nautilus
Super + Space              Rofi
Super + W                  Cierre con confirmación
Super + T                  Flotante centrado / mosaico
Super + L                  Hyprlock
Super + M                  Menú de energía
Super + Shift + Flechas    Intercambiar ventanas
Super + J                  Alternar división Dwindle
```

Consulta la referencia completa en el [Capítulo 14](Capítulo-14-Uso-Hyprland.md).

## Diagnóstico

### Errores Lua

```bash
hyprctl configerrors
```

### Waybar duplicada

```bash
pgrep -af waybar
grep -RIn 'waybar' ~/.config/hypr ~/.config/systemd/user 2>/dev/null
```

Waybar debe tener un único responsable de inicio: el autostart de Hyprland mediante UWSM.

### Fondo ausente

```bash
command -v swaybg
pgrep -af swaybg
cat ~/.config/omarchy/current/theme
```

### Tema incompleto

```bash
find ~/.config/omarchy/themes -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
hyprctl configerrors
```

No apliques manualmente un tema cuya paleta contenga colores obligatorios vacíos.

## Referencias

- Hyprland Wiki, configuración Lua: <https://wiki.hypr.land/0.56.0/Configuring/Start/>
- Hyprlock: <https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/>
- Omarchy: <https://github.com/basecamp/omarchy>
- CachyOS Wiki: <https://wiki.cachyos.org/>
