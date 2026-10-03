# Capítulo 12 - Instalación Hyprland (Actualización)

## Gestión visual de monitores

El proyecto utiliza `nwg-displays` para la administración visual y persistente de monitores.

A diferencia de versiones anteriores, ya no se utiliza `hypr-monitor-workspaces` ni se asignan automáticamente grupos fijos de espacios de trabajo según la cantidad de pantallas conectadas.

### Capacidades

- Organización visual de monitores.
- Selección del monitor principal.
- Soporte para laptops, estaciones de trabajo y configuraciones multi-monitor.
- Persistencia de la distribución entre reinicios.
- Conservación de la configuración cuando las mismas pantallas vuelven a detectarse.

### Abrir el configurador de monitores

```bash
nwg-displays
```

### Validar instalación

```bash
which nwg-displays
```

Resultado esperado:

```text
/usr/bin/nwg-displays
```

### Archivos utilizados por Hyprland

```text
~/.config/hypr/monitors.lua
~/.config/hypr/workspaces.lua
```

Estos archivos son creados por el instalador para permitir configuraciones persistentes de monitores y espacios de trabajo.

### Flujo recomendado

1. Abrir `nwg-displays`.
2. Organizar visualmente los monitores.
3. Seleccionar el monitor principal.
4. Aplicar y guardar la configuración.
5. Reiniciar sesión o reiniciar el equipo.
6. Verificar que la distribución se conserve.

### Configuración de workspaces

La asignación de espacios de trabajo es responsabilidad del usuario.

El instalador no impone rangos fijos de workspaces por monitor y no realiza reasignaciones automáticas cuando se conectan o desconectan pantallas.

La distribución queda asociada a la configuración guardada mediante `nwg-displays`.

## Capturas de pantalla

El instalador incluye herramientas de captura integradas para Hyprland.

### Dependencias

Las capturas utilizan:

- grim
- slurp
- satty

### Atajos disponibles

#### Captura de área

```text
Print