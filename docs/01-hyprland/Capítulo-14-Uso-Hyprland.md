# Capítulo 14: Uso de Hyprland

[← Cap. 13: Configuración de Waybar](Capítulo-13-Configuracion-Waybar.md) · [Índice](../_index.md) · [Cap. 15: Gestión de paquetes →](../02-aplicaciones/Capítulo-15-Gestion-Paquetes.md)

## Introducción

Esta referencia describe los atajos implementados y validados por el proyecto. La tecla modificadora principal es **Super**, normalmente identificada con el logotipo de Windows.

Los atajos se generan desde:

```text
hyprland/install/basico/hotkeys.sh
```

La configuración instalada se encuentra en:

```text
~/.config/hypr/modules/keybindings.lua
```

Después de cambiar el archivo generado:

```bash
hyprctl reload
hyprctl configerrors
```

## Aplicaciones

| Atajo | Acción |
|---|---|
| `Super + Enter` | Abrir Alacritty |
| `Super + E` | Abrir Nautilus |
| `Super + Space` | Abrir Rofi |

El selector de temas está disponible con `Super + Shift + T` o mediante el comando:

```bash
theme-switcher
```

Si se añade un atajo para esta función, debe documentarse únicamente después de implementarlo y validarlo.

## Gestión de ventanas

| Atajo | Acción |
|---|---|
| `Super + W` | Solicitar confirmación y cerrar la ventana activa |
| `Super + T` | Alternar entre mosaico y ventana flotante centrada |
| `Super + F` | Alternar pantalla completa |
| `Super + J` | Alternar la orientación del nodo Dwindle |
| `Super + clic izquierdo` | Arrastrar una ventana |
| `Super + clic derecho` | Redimensionar una ventana |

### Cierre seguro

`Super + W` abre un diálogo de Rofi con las opciones **No** y **Sí**. La acción usa el dispatcher Lua:

```lua
hl.dsp.window.close()
```

Esto evita el uso de la sintaxis histórica `killactive`, incompatible con la configuración Lua actual.

### Mosaico y flotante

`Super + T` ejecuta el helper:

```text
~/.local/bin/toggle-window-float
```

Comportamiento:

```text
Ventana en mosaico
→ activa modo flotante
→ establece un tamaño de 1100 × 700
→ centra la ventana

Ventana flotante
→ vuelve al mosaico
```

El tamaño se establece con `relative = false` para evitar un crecimiento acumulativo.

### Orientación Dwindle

`Super + J` cambia la orientación horizontal o vertical del nodo Dwindle. El proyecto habilita:

```lua
preserve_split = true
```

Sin esa opción, Hyprland puede recalcular la división y ocultar visualmente el efecto.

## Foco e intercambio de ventanas

| Atajo | Acción |
|---|---|
| `Super + ←` | Enfocar ventana a la izquierda |
| `Super + →` | Enfocar ventana a la derecha |
| `Super + ↑` | Enfocar ventana superior |
| `Super + ↓` | Enfocar ventana inferior |
| `Super + Shift + ←` | Intercambiar con la ventana de la izquierda |
| `Super + Shift + →` | Intercambiar con la ventana de la derecha |
| `Super + Shift + ↑` | Intercambiar con la ventana superior |
| `Super + Shift + ↓` | Intercambiar con la ventana inferior |

Las combinaciones con `Shift` reorganizan el árbol Dwindle. No representan mitades fijas de la pantalla.

## Espacios de trabajo

| Atajo | Acción |
|---|---|
| `Super + 1` a `Super + 9` | Ir al espacio 1 a 9 |
| `Super + 0` | Ir al espacio 10 |
| `Super + Shift + 1` a `Super + Shift + 9` | Mover la ventana al espacio 1 a 9 |
| `Super + Shift + 0` | Mover la ventana al espacio 10 |

El instalador asigna cinco espacios de trabajo por monitor. La asignación se actualiza cuando cambia la lista de monitores.

## Bloqueo y sesión

| Atajo | Acción |
|---|---|
| `Super + L` | Bloquear con Hyprlock |
| `Super + M` | Abrir menú de energía y sesión |

### Menú de energía

El menú contiene:

- Bloquear.
- Cerrar sesión.
- Suspender.
- Hibernar.
- Reiniciar.
- Apagar.
- Cancelar.

Las acciones que interrumpen el trabajo piden confirmación.

En equipos de producción, evita cerrar sesión o reiniciar salvo que sea imprescindible. Para aplicar cambios de Hyprland usa primero:

```bash
hyprctl reload
```

## Pantalla de bloqueo

El bloqueo muestra hora, fecha y un campo de contraseña. La firma es configurable desde:

```bash
~/.local/bin/lockscreen-settings
```

Modos disponibles:

- Firma gráfica privada.
- Firma gráfica más Fortune.
- Firma de texto.
- Firma de texto más Fortune.
- Fortune solamente.
- Ocultar contenido adicional.

La firma gráfica privada se busca en:

```text
~/.local/share/hyprlock/company-signature.png
```

No se almacena en Git.

## Teclas multimedia

| Tecla | Acción |
|---|---|
| Subir volumen | Aumentar 5 % con límite de 100 % |
| Bajar volumen | Reducir 5 % |
| Silenciar | Alternar silencio del dispositivo de salida |
| Subir brillo | Aumentar 5 % |
| Bajar brillo | Reducir 5 % |

Estas teclas usan `wpctl` y `brightnessctl`. Algunas se mantienen activas con la pantalla bloqueada mediante `locked = true`.

## Temas

Abre el selector:

```bash
theme-switcher
```

El selector muestra únicamente temas cuya paleta tiene todos los colores obligatorios. Al elegir uno:

- se actualizan colores;
- se actualiza el fondo;
- se guarda el tema activo;
- se recarga Hyprland;
- Waybar recarga su CSS automáticamente.

Comprueba el estado:

```bash
cat ~/.config/omarchy/current/theme
pgrep -af swaybg
pgrep -af waybar
```

Debe existir una instancia de `swaybg` y una de Waybar.

## Referencia rápida

```text
Aplicaciones
  Super + Enter              Terminal
  Super + E                  Archivos
  Super + Space              Rofi

Ventanas
  Super + W                  Cerrar con confirmación
  Super + T                  Flotante centrado / mosaico
  Super + F                  Pantalla completa
  Super + J                  Alternar división Dwindle
  Super + Flechas            Cambiar foco
  Super + Shift + Flechas    Intercambiar ventanas
  Super + clic izquierdo     Mover
  Super + clic derecho       Redimensionar

Espacios de trabajo
  Super + 1...0              Cambiar de espacio
  Super + Shift + 1...0      Mover ventana a espacio

Sesión
  Super + L                  Bloquear
  Super + M                  Menú de energía
```

## Diagnóstico

### Un atajo no responde

```bash
grep -n 'hl.bind' ~/.config/hypr/modules/keybindings.lua
hyprctl configerrors
```

### La combinación llega a la aplicación

Si una terminal imprime caracteres al pulsar una combinación, normalmente el atajo no fue cargado. Regenera el módulo y recarga:

```bash
cd ~/cachyos-install
bash hyprland/install/basico/hotkeys.sh
hyprctl reload
hyprctl configerrors
```

### `Super + J` no muestra cambios

Comprueba:

```bash
hyprctl getoption dwindle:preserve_split
```

Debe indicar que la opción está activada.

### `Super + T` aumenta demasiado la ventana

Comprueba que el helper use:

```lua
relative = false
```

No uses un incremento relativo para establecer el tamaño absoluto.

## Referencias

- Hyprland Wiki, dispatchers: <https://wiki.hypr.land/0.56.0/Configuring/Dispatchers/>
- Hyprland Wiki, Dwindle: <https://wiki.hypr.land/0.56.0/Configuring/Layouts/Dwindle-Layout/>
- Omarchy Manual, hotkeys: <https://learn.omacom.io/2/the-omarchy-manual/53/hotkeys>
