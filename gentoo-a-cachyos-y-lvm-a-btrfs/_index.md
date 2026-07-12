# 📚 Manual CachyOS: De Gentoo a CachyOS con BTRFS y Snapshots

Este manual documenta la migración completa de Gentoo a CachyOS con BTRFS, snapshots automáticos, rollbacks seguros y Hyprland como entorno gráfico.

## Estructura del Manual

### 📖 Introducción e Historia
*   [[01.gentoo-a-cachyos-y-lvm-a-btrfs|La Historia de la Migración: De Gentoo a CachyOS]] - ¿Por qué dejar Gentoo? De LVM/XFS a BTRFS.
*   [[02.gentoo-a-cachyos-y-lvm-a-btrfs|Handbook de Inicio Rápido (Particionado y Bootstrap)]] - Resumen de particionado y despliegue.

### 📑 Parte I: Sistema Base y Resiliencia (BTRFS + Snapper)

1. [[Capítulo-01-Fundamentos-de-Snapshots-y-Rollbacks-en-BTRFS|Capítulo 01: Fundamentos de BTRFS]] - Conceptos de snapshots y rollbacks.
2. [[Capítulo-02-Particionado-y-montaje-desde-el-Live-USB|Capítulo 02: Particionado y Montaje]] - Preparación de discos y montaje NVMe.
3. [[Capítulo-03-Instalación-base-con-pacstrap|Capítulo 03: Instalación Base]] - Despliegue del sistema base.
4. [[Capítulo-04-Repositorios-CachyOS|Capítulo 04: Repositorios CachyOS]] - Configuración de repos optimizados.
5. [[Capítulo-05-Configuración-del-sistema|Capítulo 05: Configuración del Sistema]] - Locales, zona horaria y red.
6. [[Capítulo-06-Configuración-de-Snapper|Capítulo 06: Configuración de Snapper]] - Automatización de snapshots.
7. [[Capítulo-07-Configuración-de-GRUB|Capítulo 07: Configuración de GRUB]] - Bootloader y boot de snapshots.
8. [[Capítulo-08-mkinitcpio|Capítulo 08: mkinitcpio]] - Initramfs adaptado.
9. [[Capítulo-09-Verificacion-de-Snapshots|Capítulo 09: Verificación de Snapshots]] - Comprobaciones iniciales.
10. [[Capítulo-10-Primer-arranque|Capítulo 10: Primer Arranque]] - Validación del sistema instalado.
11. [[Capítulo-11-Rollback|Capítulo 11: Rollback]] - Restaurar sistema en caso de desastre.

### 🎨 Parte II: Entornos de Escritorio (Dotfiles & Configuración)

#### Sección A: Hyprland (Wayland)
12. [[Capítulo-12-Instalacion-Hyprland|Capítulo 12: Instalación de Hyprland]] - Compositor y paquetes requeridos.
13. [[Capítulo-13-Configuracion-Waybar|Capítulo 13: Configuración de Waybar]] - Panel superior de Hyprland.
14. [[Capítulo-14-Uso-Hyprland|Capítulo 14: Uso de Hyprland]] - Atajos de teclado y workflow.

#### Sección B: Qtile (X11)
19. [[Capítulo-19-Instalacion-y-Uso-de-Qtile|Capítulo 19: Instalación y Uso de Qtile]] - Layouts, shortcuts (Audio Super+A) y multimonitor.

### 🛠️ Parte III: Herramientas, Administración y Gaming
15. [[Capítulo-15-Gestion-Paquetes|Capítulo 15: Gestión de Paquetes]] - Pacman y Paru en CachyOS.
16. [[Capítulo-16-Acceso-Remoto|Capítulo 16: Acceso Remoto Seguro]] - Configuración del servidor SSH.
17. [[Capítulo-17-Herramientas-CLI-modernas|Capítulo 17: Herramientas CLI Modernas]] - Utilidades de consola.
18. [[Capítulo-18-Gaming|Capítulo 18: Optimización de Gaming]] - Steam, GameMode, MangoHud y Proton-GE.


---

## Scripts Disponibles

Los scripts de instalación están en `/home/usuario/Workspace/Desarrollo/Linux/CachyOS/scripts/` (repo GitHub: `terracenter/cachyos-install`):

- `scripts/install-base.sh` — Instalación base automatizada (particionado, BTRFS, pacstrap, snapper, GRUB)
- `scripts/install-cachyos-hyprland.sh` — Instalación de Hyprland con tema Omarchy
- `scripts/install-hyprland-desktop.sh` — Configuración avanzada del escritorio Hyprland
- `scripts/install-qtile-omarchy.sh` — Instalación y configuración de Qtile con tema Omarchy
- `scripts/install-gaming.sh` — Configuración de gaming (Steam, GameMode, MangoHud)

---

## Estado: Listo para publicar en Hugo

- ✅ 19 capítulos completados en la bóveda
- ✅ Scripts en `Desarrollo/Linux/CachyOS/scripts/` (repo `terracenter/cachyos-install`)
- ✅ Frontmatter listo (con `sync: true`)
- 🔄 Antigravity: publicar en `/humanbyte-web/web-theme-Blowfish/content/manuales/cachyos/`

