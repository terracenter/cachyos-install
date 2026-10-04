# Eww como monitor de sistema en Wayland

## Estado

> **Experimental y no instalado por el escritorio Hyprland base.**

Eww, Elkowar's Wacky Widgets, permite crear widgets para X11 y Wayland. En este proyecto existe documentación histórica sobre un monitor de sistema llamado `sysmon`, pero la implementación actual de Hyprland no genera automáticamente `eww.scss`, no inicia Eww desde el autostart validado y no integra Eww en `theme-apply`.

No presentes este componente como funcional hasta que sus scripts, templates y dependencias vuelvan a incorporarse y probarse.

## Uso conceptual

Una instalación de Eww suele disponer de:

```text
~/.config/eww/eww.yuck
~/.config/eww/eww.scss
```

Comandos habituales:

```bash
eww open sysmon
```

```bash
eww close sysmon
```

```bash
eww reload
```

```bash
eww logs
```

Los nombres de widgets dependen de cada configuración. `sysmon` solo es válido si está definido en `eww.yuck`.

## Integración propuesta, no implementada

Una integración futura podría incluir:

1. Un template SCSS dentro del sistema de temas.
2. Generación de `~/.config/eww/eww.scss` desde `colors.toml`.
3. Scripts de datos instalados en `~/.local/bin`, no necesariamente en `/usr/local/bin`.
4. Inicio mediante UWSM desde el módulo de autostart.
5. Recarga en caliente únicamente cuando Eww esté ejecutándose.
6. Validaciones para impedir procesos duplicados.

Flujo conceptual:

```text
selector de temas
      ↓
theme-apply
      ↓
genera eww.scss
      ↓
eww reload
```

Este flujo no describe el estado actual del instalador.

## Scripts históricos por validar

La documentación anterior mencionaba:

```text
eww-sysinfo
eww-net-speed
eww-wan
```

Antes de documentarlos como disponibles debe comprobarse:

- Que existan en el repositorio.
- Que no expongan información sensible.
- Que manejen interfaces de red dinámicas.
- Que funcionen sin depender de servicios externos no autorizados.
- Que produzcan una salida válida para Eww.

## Privacidad

Un widget que consulte la IP pública, geolocalización o servicios externos transmite información de red. Esa función debe ser opcional, estar claramente documentada y no ejecutarse automáticamente sin conocimiento del usuario.

## Criterios para pasar a estable

- Eww está incluido en un módulo opcional claramente identificado.
- `eww.yuck` y `eww.scss` pasan validación.
- El tema activo modifica el widget correctamente.
- El autostart genera una sola instancia.
- Los pollers no bloquean ni consumen recursos excesivos.
- Existe un procedimiento de desinstalación.
- La documentación coincide con los scripts reales.

## Referencias

- Eww: <https://elkowar.github.io/eww/>
- Repositorio de Eww: <https://github.com/elkowar/eww>
