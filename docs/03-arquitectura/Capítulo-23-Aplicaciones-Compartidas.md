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

### Utilidades Compartidas (Pendientes de Auditoría)

Actualmente existen herramientas que deben evaluarse para su incorporación formal:

```text
cycle-window-size
kb-switch
pomodoro
show-keys
idle-settings
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
