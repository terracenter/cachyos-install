# Manual de CachyOS con Btrfs, Snapper y escritorios configurables

Este manual documenta la instalación y administración de CachyOS con Btrfs, snapshots, rollback, Hyprland sobre Wayland y Qtile sobre Xorg.

## Introducción

- [Capítulo 00: De Gentoo a CachyOS](00-fundamentos/Capítulo-00-De-Gentoo-a-CachyOS.md)

## Parte I: sistema base y recuperación

1. [Fundamentos de snapshots y rollback en Btrfs](00-fundamentos/Capítulo-01-Fundamentos-de-Snapshots-y-Rollbacks-en-BTRFS.md)
2. [Particionado y montaje desde el Live USB](00-fundamentos/Capítulo-02-Particionado-y-montaje-desde-el-Live-USB.md)
3. [Instalación base con pacstrap](00-fundamentos/Capítulo-03-Instalación-base-con-pacstrap.md)
4. [Repositorios de CachyOS](00-fundamentos/Capítulo-04-Repositorios-CachyOS.md)
5. [Configuración del sistema](00-fundamentos/Capítulo-05-Configuración-del-sistema.md)
6. [Configuración y mantenimiento de Snapper](00-fundamentos/Capítulo-06-Configuración-de-Snapper.md)
7. [Configuración de GRUB](00-fundamentos/Capítulo-07-Configuración-de-GRUB.md)
8. [mkinitcpio](00-fundamentos/Capítulo-08-mkinitcpio.md)
9. [Verificación de snapshots](00-fundamentos/Capítulo-09-Verificacion-de-Snapshots.md)
10. [Primer arranque](00-fundamentos/Capítulo-10-Primer-arranque.md)
11. [Rollback seguro](00-fundamentos/Capítulo-11-Rollback.md)

## Parte II: Hyprland sobre Wayland

12. [Instalación de Hyprland](01-hyprland/Capítulo-12-Instalacion-Hyprland.md)
13. [Configuración de Waybar](01-hyprland/Capítulo-13-Configuracion-Waybar.md)
14. [Uso de Hyprland](01-hyprland/Capítulo-14-Uso-Hyprland.md)

## Parte III: administración y aplicaciones

15. [Gestión de paquetes](02-aplicaciones/Capítulo-15-Gestion-Paquetes.md)
16. [Acceso remoto](02-aplicaciones/Capítulo-16-Acceso-Remoto.md)
17. [Herramientas CLI modernas](02-aplicaciones/Capítulo-17-Herramientas-CLI-modernas.md)
18. [Gaming en CachyOS](02-aplicaciones/Capítulo-18-Gaming.md)

## Parte IV: Qtile y componentes opcionales

19. [Instalación y uso de Qtile sobre Xorg](02-aplicaciones/Capítulo-19-Instalacion-y-Uso-de-Qtile.md)
20. [Eww en Xorg y Wayland](02-aplicaciones/Capítulo-20-Eww-en-Xorg-y-Wayland.md)

## Parte V: arquitectura y evolución

21. [Arquitectura del Proyecto](03-arquitectura/Capítulo-21-Arquitectura-del-Proyecto.md)
22. [Sistema de Temas](03-arquitectura/Capítulo-22-Sistema-de-Temas.md)
23. [Aplicaciones Compartidas](03-arquitectura/Capítulo-23-Aplicaciones-Compartidas.md)
24. [ROADMAP del Proyecto](03-arquitectura/Capítulo-24-ROADMAP.md)

## Scripts principales

```text
install.sh
base/install-base.sh
hyprland/install-hyprland-desktop.sh
hyprland/install-hyprland-apps.sh
qtile/install-qtile-omarchy.sh
```

## Estado de los componentes

```text
Sistema base        Documentado y validado
Hyprland            Documentado y validado
Qtile sobre Xorg    Implementado; pendiente de paridad completa con Hyprland
Eww en Qtile        Implementado; debe mantenerse opcional
Eww en Hyprland     Experimental; no instalado por defecto
```

## Cómo usar la documentación

- El código es la fuente de verdad de la implementación.
- Revisa las advertencias antes de ejecutar comandos destructivos.
- Sustituye los dispositivos de ejemplo por los detectados en tu equipo.
- Los snapshots no sustituyen respaldos externos.
- Evita cierres de sesión y reinicios innecesarios en equipos de producción.
