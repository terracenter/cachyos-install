# Capítulo 22 - Sistema de Temas

## Objetivo

Todos los temas del proyecto deben proporcionar una experiencia visual coherente en todo el sistema.

El objetivo es que un único tema controle:

```text
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

---

## Fuente de Verdad

Cada tema se define mediante:

```text
hyprland/themes/<tema>/colors.toml
```

Ejemplo:

```text
hyprland/themes/nord/colors.toml
hyprland/themes/tokyo-night/colors.toml
hyprland/themes/astronaut/colors.toml
```

---

## Aplicación de Temas

La aplicación de temas se realiza mediante:

```text
~/.local/bin/theme-apply
```

Este script:

- Actualiza Hyprland.
- Actualiza Waybar.
- Actualiza GTK.
- Actualiza iconos.
- Actualiza cursores.
- Actualiza Mako.
- Actualiza wallpaper.
- Actualiza SDDM.
- Actualiza GRUB.

---

## Selección de Temas

El selector gráfico utiliza:

```text
~/.local/bin/theme-switcher
```

y muestra únicamente temas válidos instalados.

---

## Temas Disponibles

Actualmente el proyecto incluye:

```text
cachyos-fluent
catppuccin
catppuccin-latte
ethereal
everforest
flexoki-light
gruvbox
hackerman
kanagawa
last-horizon
lumon
matte-black
miasma
nord
osaka-jade
retro-82
ristretto
rose-pine
solitude
tokyo-night
vantablack
white
astronaut
```

---

## Astronaut

Astronaut es el tema visual principal del proyecto.

Incluye:

```text
Wallpaper propio
GRUB Astronaut
SDDM Astronaut
Paleta propia
```

Objetivo:

```text
GRUB
↓
SDDM
↓
Escritorio
```

como una experiencia visual continua.

---

## Mapas de Integración

### SDDM

```text
~/.local/share/omarchy-local/sddm-bg-map
```

Relaciona:

```text
Tema
↓
Fondo SDDM
```

---

### GRUB

```text
~/.local/share/omarchy-local/grub-theme-map
```

Relaciona:

```text
Tema
↓
Tema GRUB
```

---

## Regla de Desarrollo

Al agregar un tema nuevo deben existir:

```text
colors.toml
wallpaper
mapeo SDDM
mapeo GRUB
```

antes de considerarlo terminado.

No deben existir temas parciales.
