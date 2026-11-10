# Roadmap — cachyos-install

## Objetivo general

Instalador reproducible basado en CachyOS + Omarchy + personalizaciones propias: funcional, fácil de operar y de mantener, y visualmente coherente (UEFI → GRUB → SDDM → wallpaper → Waybar → GTK → aplicaciones).

## Estado actual

- Estado: activo.
- Próxima acción: validar la instalación completa (base + Hyprland) en la laptop de pruebas.

## Fase 1 — Sistema base (`base/install-base.sh`)

- [x] Particionado BTRFS con subvolúmenes, pacstrap y repositorios CachyOS.
- [x] Snapper, grub-btrfs y rollback (`btrfs-rollback`).
- [x] GRUB y mkinitcpio.
- [x] El selector de disco responde al teclado cuando se lanza desde `install.sh`.
- [x] El asistente pide el nombre completo del usuario.
- [x] Cada pregunta del asistente tiene opción de regresar, y Cancelar nunca asigna un valor por defecto.
- [ ] La zona horaria se detecta por IP y queda marcada como recomendada.
- [ ] El idioma y el teclado quedan recomendados según la zona horaria y el idioma elegidos.
- [ ] Segunda confirmación, explícita, antes de borrar el disco.
- [ ] Instalación base validada en hardware real.

## Fase 2 — Escritorio Hyprland (`hyprland/`)

- [x] Instalador base modular: `install-hyprland-desktop.sh` con `install/basico`, `install/configuracion` e `install/rest`.
- [x] Instalador de aplicaciones separado: `install-hyprland-apps.sh`.
- [x] Monitoreo de cambios de Omarchy: `check-omarchy-updates.sh`.
- [x] Waybar, audio por aplicación, capturas de pantalla y monitores persistentes.
- [x] El instalador de aplicaciones escribe su log sin requerir root.
- [ ] Escritorio y aplicaciones validados en hardware real.
- [ ] Issues abiertos: #2 (volumen), #3 (menú Pantalla y Energía), #4 (mover ventanas en dwindle).

## Fase 3 — Temas y experiencia visual

- [x] Sistema de temas, SDDM Astronaut y GRUB Astronaut.
- [ ] Auditoría completa de todos los temas.
- [ ] Revisión de los mapas SDDM y GRUB.
- [ ] Validación visual tema por tema.

## Fase 4 — Aplicaciones compartidas y Eww

- [x] kb-switch: se adopta la solución nativa de Omarchy.
- [x] cycle-window-size: descartado (sin implementación ni necesidad concreta).
- [ ] show-keys: Hyprland migra a la solución de Omarchy; Qtile mantiene la suya.
- [ ] idle-settings: Qtile mantiene la suya; Hyprland usa hypridle/hyprlock.
- [ ] pomodoro: sin implementación; posible desarrollo futuro.
- [ ] Eww: migrar desde Qtile y convertirlo en aplicación compartida.

## Fase 5 — Qtile (X11)

- [x] Instalador y desinstalador de Qtile.
- Se mantiene como entorno alternativo; sin trabajo nuevo planificado.

## Regla de calidad

Rama → desarrollo → validación → documentación → commit → push → PR → merge a `main` → borrar la rama.

## Bloqueos

- Ninguno en el código. La validación en hardware depende de la laptop de pruebas.
