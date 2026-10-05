# Capítulo 23 - Aplicaciones Compartidas

## Objetivo

Las aplicaciones compartidas son herramientas que no pertenecen exclusivamente a Hyprland ni a Qtile.

Deben funcionar en ambos escritorios siempre que sea posible.

---

## Filosofía

No duplicar implementaciones.

Incorrecto:

```text
Hyprland → aplicación A
Qtile     → aplicación A distinta
```

Correcto:

```text
Aplicación Compartida
          ↓
    Hyprland y Qtile
```

---

## Herramientas Actuales

### Gestión Visual

```text
theme-switcher
wallpaper-switcher
sddm-bg-switcher
grub-theme-switcher
```

---

### Capturas de Pantalla

```text
screenshot-area
screenshot-copy
screenshot-full
screenshot-window
```

---

### Pantalla de Bloqueo

```text
render-lockscreen
lockscreen-content
lockscreen-settings
```

---

### Sesión

```text
power-menu
confirm-close-window
```

---

### Utilidades Compartidas

Herramientas auditadas:

```text
✅ kb-switch
  Adoptar solución nativa de Omarchy.

❌ cycle-window-size
  Descartado.
  Motivo:
  - No existe implementación en el proyecto.
  - No existe implementación equivalente identificada en Omarchy.

🟡 show-keys
  Adopción parcial.
  - Hyprland: migrar a la solución nativa de Omarchy.
  - Qtile: mantener implementación actual.
```

Estado actual:

```text
🟡 idle-settings
  Auditoría completada.
  - Qtile: mantener implementación actual.
  - Hyprland: Omarchy utiliza hypridle/hyprlock.
  - No se identificó una herramienta equivalente de configuración.
```

Pendientes de auditoría:

```text
🟡 pomodoro
  Auditoría completada.
  - No existe implementación actual.
  - No se identificó una solución equivalente en Omarchy.
  - La funcionalidad sigue considerándose útil para productividad.
```


---

## Eww

Eww se considera una aplicación compartida.

Objetivo:

```text
Widget persistente
↓
Bajo consumo
↓
No interferir con ventanas
```

Similar al uso tradicional de Conky.

---

## Regla de Integración

Antes de incorporar una aplicación compartida:

```text
Instalar
↓
Documentar
↓
Validar
↓
Integrar
```

Ninguna herramienta debe depender de configuraciones manuales fuera del repositorio.
