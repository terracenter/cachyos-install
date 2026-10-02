# Capítulo 13: Configuración de Waybar

[← Cap. 12: Instalación de Hyprland](Capítulo-12-Instalacion-Hyprland.md) · [Índice](./_index.md) · [Cap. 14: Uso de Hyprland →](Capítulo-14-Uso-Hyprland.md)

## Introducción

Waybar es la barra de estado de la sesión Hyprland. El módulo:

```text
hyprland/install/basico/top-bar.sh
```

genera:

```text
~/.config/waybar/
├── config.jsonc
└── style.css
```

La configuración está integrada con los temas del proyecto y utiliza JetBrainsMono Nerd Font.

## Distribución actual

```text
Izquierda                    Centro                     Derecha
Lanzador + workspaces        Reloj        Red · Audio · CPU · RAM · Batería · Tray · Energía
```

### Módulos de la izquierda

- `custom/launcher`: abre Rofi.
- `hyprland/workspaces`: muestra los espacios de trabajo de Hyprland.

Los espacios se asignan dinámicamente, cinco por monitor. No se codifican cinco workspaces globales fijos en Waybar.

### Módulo central

- `clock`: muestra día y hora.
- El formato alternativo muestra la fecha.

### Módulos de la derecha

- `network`: red cableada, Wi-Fi o desconectada.
- `pulseaudio`: volumen y acceso al menú de audio integrado con `Rofi`.
- `cpu`: uso de CPU.
- `memory`: uso de memoria.
- `battery`: carga y estado de batería cuando existe.
- `tray`: bandeja de aplicaciones.
- `custom/power`: abre el menú seguro de sesión y energía.

## Lanzador

El lanzador abre Rofi:

```text
Clic en el icono → rofi -show drun
```

El atajo equivalente es:

```text
Super + Space
```

## Botón de energía

El módulo `custom/power` ejecuta:

```text
~/.local/bin/power-menu
```

El menú muestra bloquear, cerrar sesión, suspender, hibernar, reiniciar, apagar y cancelar. Las acciones críticas piden confirmación.

## Colores dinámicos

`style.css` importa el archivo generado por el tema activo:

```css
@import "../omarchy/current/waybar-colors.css";
```

El archivo se genera a partir de:

```text
~/.config/omarchy/themes/<tema>/colors.toml
```

El template define variables como:

```css
@define-color foreground ...;
@define-color background ...;
@define-color surface ...;
@define-color accent ...;
@define-color warning ...;
@define-color critical ...;
```

La configuración incluye:

```json
"reload_style_on_change": true
```

Por ello, Waybar recarga el CSS cuando cambia el tema sin crear un proceso nuevo.

## Inicio único mediante UWSM

Waybar se inicia desde:

```text
~/.config/hypr/modules/autostart.lua
```

mediante:

```lua
hl.exec_cmd("uwsm app -- waybar")
```

El sistema de temas no debe ejecutar `waybar` ni reiniciarla. Esto evita dos barras superpuestas después de instalar o cambiar el tema.

Comprueba los procesos:

```bash
pgrep -af waybar
```

Debe aparecer una sola instancia. Con varios monitores, una instancia puede dibujar una barra en cada salida. Eso no significa que existan procesos duplicados.

## Aplicar la configuración

Ejecuta únicamente el módulo de Waybar:

```bash
cd ~/cachyos-install
bash hyprland/install/basico/top-bar.sh
```

Si Waybar aún no está ejecutándose:

```bash
uwsm app -- waybar &
```

Evita iniciar Waybar repetidamente sin comprobar primero:

```bash
pgrep -af waybar
```

## Actualización de estilos

Para cambiar colores, usa el selector de temas:

```bash
theme-switcher
```

No es necesario matar Waybar. `reload_style_on_change` observa el archivo importado y aplica los nuevos colores.

## Diagnóstico

### Dos procesos de Waybar

```bash
pgrep -af waybar
```

Busca responsables adicionales:

```bash
grep -RIn 'waybar' \
  ~/.config/hypr \
  ~/.config/systemd/user \
  ~/.config/uwsm \
  2>/dev/null
```

La configuración válida del proyecto debe mostrar el inicio en `modules/autostart.lua`. Los archivos `.bak` no son cargados mediante `require()` y no deben contarse como autostart activo.

### CSS no aplicado

Comprueba los archivos:

```bash
ls -l \
  ~/.config/waybar/style.css \
  ~/.config/omarchy/current/waybar-colors.css
```

Revisa variables sin procesar:

```bash
grep -RIn '{{[^}]*}}' ~/.config/omarchy/current 2>/dev/null
```

No debe haber salida.

### Iconos ausentes

```bash
fc-match 'JetBrainsMono Nerd Font'
```

Si no está instalada:

```bash
sudo pacman -S --needed ttf-jetbrains-mono-nerd
```

### Errores de configuración

Ejecuta Waybar temporalmente en modo detallado solo para diagnóstico:

```bash
waybar -l debug 2>&1 | tee /tmp/waybar-debug.log
```

No mantengas dos instancias activas durante la prueba.

## Buenas prácticas

- UWSM es el único responsable de iniciar Waybar.
- El sistema de temas solo modifica archivos de estilo.
- No uses `pkill waybar && waybar &` para cambios de color.
- Valida procesos antes de reiniciar la barra.
- No cierres sesión ni reinicies para aplicar CSS.
- Mantén la configuración generada dentro de `~/.config/waybar/`.

## Referencias

- Waybar manual: <https://man.archlinux.org/man/waybar.5.en>
- Waybar: <https://github.com/Alexays/Waybar>
- Hyprland Wiki: <https://wiki.hypr.land/>
