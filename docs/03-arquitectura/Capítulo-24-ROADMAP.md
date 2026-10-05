# Capítulo 24 - ROADMAP

## Estado Actual

### Completado

✅ CachyOS Base

✅ BTRFS

✅ Snapper

✅ Rollback

✅ GRUB

✅ Hyprland

✅ Qtile

✅ Monitores persistentes

✅ Waybar

✅ Audio por aplicación

✅ Screenshots

✅ SDDM Astronaut

✅ GRUB Astronaut

✅ Sistema de temas

✅ Documentación técnica

---

## Trabajo Activo

### Sistema de Temas

Objetivo:

```text
Tema
↓
Wallpaper
↓
Waybar
↓
GTK
↓
Hyprland
↓
Terminal
↓
Notificaciones
↓
SDDM
↓
GRUB
```

### Pendientes

- Auditoría completa de todos los temas.
- Revisión de mapas SDDM.
- Revisión de mapas GRUB.
- Validación visual tema por tema.

---

## Aplicaciones Compartidas

### Evaluados:

```text
✅ kb-switch
  Adoptar solución nativa de Omarchy.

❌ cycle-window-size
  Descartado.
  Motivo:
  - No existe implementación en el proyecto.
  - No existe implementación equivalente identificada en Omarchy.
  - No se encontró una necesidad concreta que justifique mantenerlo en el roadmap.

🟡 show-keys
  Adopción parcial.
  - Hyprland: migrar a la solución nativa de Omarchy.
  - Qtile: mantener implementación actual.
  - Pendiente validar la migración definitiva.

``` 

### Estado actual:

```text
🟡 idle-settings
  Auditoría completada.
  - Qtile: mantener implementación actual.
  - Hyprland: Omarchy utiliza hypridle/hyprlock.
  - No se identificó una herramienta equivalente de configuración.
```

### Pendientes de evaluación:

```text
⏳ pomodoro
```


### Objetivo:

```text
Integrar o descartar
```

según aporten valor al proyecto.

---

## Eww

Pendiente:

```text
Migrar desde Qtile
↓
Convertir en aplicación compartida
```

Objetivos:

- Siempre visible.
- No interferir con ventanas.
- Bajo consumo.
- Integración con temas.

---

## Experiencia Visual

Objetivo final:

```text
UEFI
↓
GRUB Astronaut
↓
SDDM Astronaut
↓
Wallpaper
↓
Waybar
↓
GTK
↓
Aplicaciones
```

como una experiencia visual coherente.

---

## Regla de Calidad

Todo cambio debe seguir:

```text
Rama
↓
Desarrollo
↓
Validación
↓
Documentación
↓
Commit
↓
Push
↓
Merge a main
↓
Eliminar rama
```

No deben existir cambios permanentes fuera del repositorio.

---

## Objetivo General

Crear una distribución basada en:

```text
CachyOS
+
Omarchy
+
Personalizaciones propias
```

que sea:

- Funcional.
- Reproducible.
- Fácil de operar.
- Fácil de mantener.
- Visualmente coherente.
