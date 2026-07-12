# cachyos-install

Scripts de instalación automatizada para **CachyOS** con BTRFS, snapshots Snapper, entornos gráficos Hyprland (Wayland) y Qtile (X11), plus herramientas de productividad y gaming.

Desarrollados y validados en hardware real como complemento del manual técnico completo disponible en **[humanbyte.net](https://humanbyte.net/manuales/de-gentoo-a-cachyos/)**.

---

## Instalación rápida

```bash
# Paso 1 — desde el Live USB de CachyOS (root, con red ya configurada)
curl -fsSL https://raw.githubusercontent.com/terracenter/cachyos-install/main/bootstrap.sh | sudo bash
```

Al terminar, **reinicia** e inicia sesión con el usuario que creaste. Luego:

```bash
# Paso 2 — ya en el sistema instalado (usuario normal, no root)
curl -fsSL https://raw.githubusercontent.com/terracenter/cachyos-install/main/bootstrap-desktop.sh | bash
```

El instalador de escritorio te guiará a través de un menú interactivo para elegir:
1. **Entorno de escritorio** — Hyprland (Wayland) o Qtile (X11)
2. **Herramientas de gaming** — Steam, GameMode, MangoHud, Proton-GE (opcional)

---

## Estructura del proyecto

```
cachyos-install/
├── bootstrap.sh                      ← Bootstrapper remoto Fase 1 (clona + delega a install.sh)
├── install.sh                        ← Punto de entrada Fase 1 (base system only)
├── bootstrap-desktop.sh              ← Bootstrapper remoto Fase 2 (clona + delega a install-desktop.sh)
├── install-desktop.sh                ← Punto de entrada Fase 2 (post-reboot, usuario normal)
├── README.md
├── LICENSE
├── base/
│   └── install-base.sh              (Sistema base: BTRFS, GRUB, Snapper)
├── hyprland/
│   ├── install-cachyos-hyprland.sh  (Entorno Hyprland + paquetes)
│   ├── install-hyprland-desktop.sh  (Desktop completo + dotfiles)
│   └── themes/                      (Temas Catppuccin, Nord, etc.)
├── qtile/
│   ├── install-qtile-omarchy.sh     (Entorno Qtile + configs)
│   └── configs/                     (alacritty, omarchy, picom, qtile, rofi)
├── gaming/
│   └── install-gaming.sh            (Steam, GameMode, MangoHud, Proton-GE)
└── gentoo-a-cachyos-y-lvm-a-btrfs/  (Documentación de migración)
```

---

## Hyprland vs Qtile

### Hyprland (Wayland) — Recomendado
- **Moderno:** compositor Wayland nativo
- **Mejor rendimiento:** GPU directo, menos overhead
- **Ideal para:** hardware nuevo, apps modernas (VS Code, Firefox, etc.)
- **Drawback:** algunas apps antiguas aún no soportan Wayland

### Qtile (X11)
- **Compatible:** X11 tradicional
- **Todas las apps:** soporte universal (incluso legacy)
- **Overhead:** servidor X11 consume más recursos
- **Ideal para:** hardware antiguo, apps que requieren X11 nativo

---

## Requisitos

- Live USB de CachyOS
- Conexión a internet
- Disco destino identificado (`lsblk` antes de comenzar)

> **Advertencia:** Estos scripts realizan operaciones destructivas (formateo, particionado). Lee completo y valida antes de ejecutar.

---

## Scripts individuales

Si prefieres ejecutar fases específicas:

| Ubicación | Descripción |
|-----------|-------------|
| `base/install-base.sh` | Sistema base: particionado BTRFS, subvolúmenes, pacstrap, GRUB, Snapper |
| `hyprland/install-cachyos-hyprland.sh` | Packages Hyprland + Waybar + bootsplash Omarchy |
| `hyprland/install-hyprland-desktop.sh` | Desktop completo: dotfiles + CLI modernas + config avanzada |
| `qtile/install-qtile-omarchy.sh` | Entorno Qtile + configs Omarchy + temas |
| `gaming/install-gaming.sh` | Stack gaming: Steam, GameMode, MangoHud, Proton-GE, Lutris, Wine |

---

## Temas (`hyprland/themes/`)

Configuraciones de color precargadas para Hyprland (GTK, terminal, wallpapers). Instaladas automáticamente por los scripts.

---

## Manual Completo: De Gentoo a CachyOS (Estructura de Libro)

El handbook técnico detallado está disponible en la carpeta [gentoo-a-cachyos-y-lvm-a-btrfs/](gentoo-a-cachyos-y-lvm-a-btrfs/). Para facilitar la lectura, el manual está organizado en las siguientes partes:

### 📖 Introducción e Historia
*   **[La Historia de la Migración: De Gentoo a CachyOS](gentoo-a-cachyos-y-lvm-a-btrfs/01.gentoo-a-cachyos-y-lvm-a-btrfs.md)** - ¿Por qué dejar Gentoo? De la rigidez de LVM/XFS a la flexibilidad de BTRFS.
*   **[Handbook de Inicio Rápido (Particionado y Bootstrap)](gentoo-a-cachyos-y-lvm-a-btrfs/02.gentoo-a-cachyos-y-lvm-a-btrfs.md)** - Resumen de particionado y despliegue rápido.

### 📑 Parte I: Sistema Base y Resiliencia (BTRFS + Snapper)
*   **[Capítulo 01: Fundamentos de BTRFS](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-01-Fundamentos-de-Snapshots-y-Rollbacks-en-BTRFS.md)** - Conceptos clave de snapshots y rollbacks sobre sistemas de archivos BTRFS.
*   **[Capítulo 02: Particionado y Montaje](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-02-Particionado-y-montaje-desde-el-Live-USB.md)** - Preparación del disco NVMe y montaje optimizado desde el entorno Live USB.
*   **[Capítulo 03: Instalación Base](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-03-Instalación-base-con-pacstrap.md)** - Despliegue del sistema operativo base utilizando `pacstrap`.
*   **[Capítulo 04: Repositorios CachyOS](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-04-Repositorios-CachyOS.md)** - Configuración de repositorios optimizados para arquitecturas de CPU específicas.
*   **[Capítulo 05: Configuración del Sistema](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-05-Configuración-del-sistema.md)** - Configuración regional, locales, zona horaria y red.
*   **[Capítulo 06: Configuración de Snapper](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-06-Configuración-de-Snapper.md)** - Configuración de políticas de snapshots y limpieza automática.
*   **[Capítulo 07: Configuración de GRUB](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-07-Configuración-de-GRUB.md)** - Configuración del gestor de arranque e integración con `grub-btrfs`.
*   **[Capítulo 08: mkinitcpio](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-08-mkinitcpio.md)** - Creación del initramfs adaptado a BTRFS.
*   **[Capítulo 09: Verificación de Snapshots](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-09-Verificacion-de-Snapshots.md)** - Validación inicial del funcionamiento de las capturas del sistema.
*   **[Capítulo 10: Primer Arranque](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-10-Primer-arranque.md)** - Retirada del Live USB y validación del sistema en caliente.
*   **[Capítulo 11: Rollback (Revertir el sistema)](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-11-Rollback.md)** - Procedimiento paso a paso para restaurar un snapshot anterior en caso de desastre.

### 🎨 Parte II: Entornos de Escritorio (Dotfiles & Configuración)

#### Sección A: Hyprland (Wayland - Moderno)
*   **[Capítulo 12: Instalación de Hyprland](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-12-Instalacion-Hyprland.md)** - Instalación del compositor y de los paquetes requeridos.
*   **[Capítulo 13: Configuración de Waybar](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-13-Configuracion-Waybar.md)** - Personalización del panel superior de Hyprland.
*   **[Capítulo 14: Uso de Hyprland](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-14-Uso-Hyprland.md)** - Atajos de teclado esenciales, atajos rápidos y workflow en Wayland.

#### Sección B: Qtile (X11 - Compatible)
*   **[Capítulo 19: Instalación y Uso de Qtile](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-19-Instalacion-y-Uso-de-Qtile.md)** - Configuración de Qtile, layouts, shortcuts (`Super + A` para audio) y multimonitor en X11.

### 🛠️ Parte III: Herramientas, Administración y Gaming
*   **[Capítulo 15: Gestión de Paquetes](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-15-Gestion-Paquetes.md)** - Buenas prácticas en el uso de `pacman` y `paru` en CachyOS.
*   **[Capítulo 16: Acceso Remoto Seguro](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-16-Acceso-Remoto.md)** - Configuración del servidor SSH seguro.
*   **[Capítulo 17: Herramientas CLI Modernas](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-17-Herramientas-CLI-modernas.md)** - Uso de utilidades de productividad en consola (btop, fastfetch, etc.).
*   **[Capítulo 18: Optimización de Gaming](gentoo-a-cachyos-y-lvm-a-btrfs/Capítulo-18-Gaming.md)** - Configuración de Steam, GameMode, MangoHud y Proton-GE.

---

## Licencia

Este proyecto está licenciado bajo los términos de la **GNU Affero General Public License v3.0**.
Ver el archivo [LICENSE](LICENSE) para más detalles.


