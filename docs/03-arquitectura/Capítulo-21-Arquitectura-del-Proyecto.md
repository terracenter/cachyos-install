# Capítulo 21 - Arquitectura del Proyecto

## Objetivo

El objetivo del proyecto es proporcionar una instalación de CachyOS reproducible, documentada, visualmente coherente y sencilla de mantener.

La filosofía general es:

```text
CachyOS
+
Omarchy
+
Personalizaciones propias
+
Documentación integrada
+
Automatización
```

---

## Capas del Proyecto

### Base

Responsable de:

- Particionado
- BTRFS
- Snapper
- GRUB
- mkinitcpio
- Configuración inicial del sistema

Ubicación:

```text
base/
```

---

### Aplicaciones Compartidas

Componentes independientes del escritorio utilizado.

Ejemplos:

- Theme Switcher
- Wallpaper Switcher
- SDDM Background Switcher
- GRUB Theme Switcher
- Screenshots
- Pomodoro
- Show Keys
- Eww

Objetivo:

```text
Una sola implementación
↓
Hyprland
Qtile
```

---

### Hyprland

Responsable de:

- Waybar
- Monitores persistentes
- Workspaces
- Audio por aplicación
- Temas
- Capturas de pantalla

Ubicación:

```text
hyprland/
```

---

### Qtile

Responsable únicamente de:

- Configuración específica de Qtile
- Atajos específicos de Qtile
- Componentes dependientes de X11

Ubicación:

```text
qtile/
```

---

## Proceso de Desarrollo

Todo cambio debe seguir la secuencia:

```text
Rama
↓
Desarrollo
↓
Validación
↓
Commit
↓
Push
↓
Merge a main
↓
Eliminación de ramas
```

No deben existir cambios manuales permanentes fuera del repositorio.

---

## Principios

### Reproducibilidad

Una instalación nueva debe producir el mismo resultado que una instalación existente.

### Mantenibilidad

El proyecto debe evitar configuraciones duplicadas y lógica repetida.

### Coherencia Visual

El sistema debe mantener una experiencia uniforme desde el arranque hasta el escritorio.

```text
GRUB
↓
SDDM
↓
Wallpaper
↓
Waybar
↓
GTK
↓
Aplicaciones
```
