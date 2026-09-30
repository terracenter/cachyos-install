# De Gentoo a CachyOS

Este repositorio documenta y automatiza una instalación de CachyOS con Btrfs, Snapper y escritorios configurables. El proyecto nació como una migración personal desde Gentoo, pero la implementación actual debe entenderse como un instalador modular y auditable.

## Punto de entrada

Clona el repositorio, revisa el código y ejecuta:

```bash
git clone git@github.com:terracenter/cachyos-install.git
cd cachyos-install
./install.sh
```

No se recomienda ejecutar instaladores remotos mediante construcciones como:

```text
curl URL | sudo bash
```

Descargar y revisar el repositorio permite conocer qué comandos se ejecutarán, conservar una versión concreta y verificar los cambios con Git.

## Componentes principales

### Sistema base

- Instalación desde un Live USB de CachyOS.
- Particionado GPT y UEFI.
- Btrfs con subvolúmenes separados.
- LUKS2 opcional.
- Swapfile compatible con Btrfs.
- Kernel de CachyOS.
- GRUB y `grub-btrfs`.
- Snapper y `snap-pac`.
- Helper de rollback con conservación del sistema anterior.

### Hyprland

- Sesión Wayland.
- Configuración modular en Lua.
- Waybar, Rofi, Hyprlock y SDDM.
- Monitores y espacios de trabajo dinámicos.
- Temas y fondos aplicados desde Rofi.
- Menú seguro de bloqueo, sesión y energía.

### Qtile

El repositorio conserva una implementación alternativa de Qtile sobre X11. Su documentación debe validarse contra los scripts actuales antes de considerarla equivalente al flujo de Hyprland.

### Aplicaciones opcionales

Las aplicaciones de desarrollo, oficina, multimedia, gaming y virtualización se mantienen separadas del escritorio base. Esta separación reduce cambios innecesarios y facilita las pruebas.

## Documentación

La documentación fuente reside en:

```text
docs/
```

La guía comienza en:

```text
docs/_index.md
```

Los capítulos cubren instalación base, Btrfs, Snapper, rollback, Hyprland, Waybar, paquetes, acceso remoto, CLI, gaming y Qtile.

## Seguridad y mantenimiento

- Los snapshots no sustituyen respaldos externos.
- Los comandos destructivos requieren identificar el disco correcto.
- Las actualizaciones deben ser completas.
- Los paquetes AUR deben revisarse antes de compilarse.
- Los reinicios y cierres de sesión deben evitarse en equipos de producción salvo que sean necesarios.
- Los cambios nuevos se desarrollan en ramas y se integran en `main` después de validarlos.

## Contribuciones

Antes de abrir un cambio:

1. Crea una rama desde `main`.
2. Mantén commits pequeños y descriptivos.
3. Ejecuta `bash -n` y ShellCheck sobre scripts modificados.
4. Valida `git diff --check`.
5. Actualiza la documentación relacionada.
6. No incluyas credenciales, firmas empresariales ni datos privados.

## Estado del proyecto

El código es la fuente de verdad de la implementación. Cuando exista una diferencia entre un capítulo y los scripts, revisa el módulo correspondiente antes de ejecutar instrucciones.
