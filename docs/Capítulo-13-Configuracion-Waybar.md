# Capítulo 13 - Configuración Waybar (Actualización)

## Workspaces y monitores

Waybar muestra los espacios de trabajo activos definidos por Hyprland.

La distribución de workspaces depende de la configuración persistente de monitores almacenada mediante `nwg-displays`.

### Características

- Compatible con uno o varios monitores.
- Respeta el monitor principal configurado por el usuario.
- Mantiene la distribución tras reinicios.
- Refleja los workspaces activos de Hyprland.

Waybar no crea, mueve ni reasigna espacios de trabajo automáticamente.

La organización de monitores y workspaces se administra desde:

```bash
nwg-displays
```
