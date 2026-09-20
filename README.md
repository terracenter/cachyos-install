# cachyos-install

![Licencia](https://img.shields.io/badge/licencia-AGPL--3.0--or--later-blue)
![Estado](https://img.shields.io/badge/estado-Operativo-orange)
![Stack](https://img.shields.io/badge/stack-Bash%20%7C%20BTRFS%20%7C%20Arch-informational)

Scripts de instalación automatizada para **CachyOS** con BTRFS, snapshots Snapper, entornos gráficos Hyprland (Wayland) y Qtile (X11), plus herramientas de productividad y gaming.

Desarrollados y validados en hardware real como complemento del manual técnico completo disponible en **[humanbyte.net](https://humanbyte.net/manuales/de-gentoo-a-cachyos/)**.

---

## Instalación rápida

```bash
# Paso 1 — desde el Live USB de CachyOS (root, con red ya configurada)
# 1. Instalar git si no está presente
pacman -Sy --noconfirm git

# 2. Clonar el repositorio
git clone https://github.com/terracenter/cachyos-install.git /tmp/cachyos-install
cd /tmp/cachyos-install

# 3. Ejecutar el menú interactivo como root (Fase 1)
sudo ./install.sh
```

Desde el menú, selecciona **Opción 1** para la instalación base. Al terminar, **reinicia** e inicia sesión con el usuario que creaste. Luego:

```bash
# Paso 2 — ya en el sistema instalado (usuario normal, no root)
# 1. Clonar el repositorio localmente
git clone https://github.com/terracenter/cachyos-install.git ~/cachyos-install
cd ~/cachyos-install

# 2. Ejecutar el menú interactivo como usuario normal (Fases de Escritorio y Apps)
./install.sh
```

El instalador te guiará a través de un menú interactivo para instalar los entornos de escritorio (Hyprland o Qtile), suite de gaming y aplicaciones.

---

## Estructura del proyecto

```
cachyos-install/
├── install.sh                        ← Punto de entrada ÚNICO interactivo para TODAS las fases
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
└── docs/  (Documentación de migración)
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

El handbook técnico detallado está disponible en la carpeta [docs/](docs/). Para facilitar la lectura, el manual está organizado en las siguientes partes:

### 📖 Introducción e Historia
*   **[La Historia de la Migración: De Gentoo a CachyOS](docs/01.gentoo-a-cachyos-y-lvm-a-btrfs.md)** - ¿Por qué dejar Gentoo? De la rigidez de LVM/XFS a la flexibilidad de BTRFS.
*   **[Handbook de Inicio Rápido (Particionado y Bootstrap)](docs/02.gentoo-a-cachyos-y-lvm-a-btrfs.md)** - Resumen de particionado y despliegue rápido.

### 📑 Parte I: Sistema Base y Resiliencia (BTRFS + Snapper)
*   **[Capítulo 01: Fundamentos de BTRFS](docs/Capítulo-01-Fundamentos-de-Snapshots-y-Rollbacks-en-BTRFS.md)** - Conceptos clave de snapshots y rollbacks sobre sistemas de archivos BTRFS.
*   **[Capítulo 02: Particionado y Montaje](docs/Capítulo-02-Particionado-y-montaje-desde-el-Live-USB.md)** - Preparación del disco NVMe y montaje optimizado desde el entorno Live USB.
*   **[Capítulo 03: Instalación Base](docs/Capítulo-03-Instalación-base-con-pacstrap.md)** - Despliegue del sistema operativo base utilizando `pacstrap`.
*   **[Capítulo 04: Repositorios CachyOS](docs/Capítulo-04-Repositorios-CachyOS.md)** - Configuración de repositorios optimizados para arquitecturas de CPU específicas.
*   **[Capítulo 05: Configuración del Sistema](docs/Capítulo-05-Configuración-del-sistema.md)** - Configuración regional, locales, zona horaria y red.
*   **[Capítulo 06: Configuración de Snapper](docs/Capítulo-06-Configuración-de-Snapper.md)** - Configuración de políticas de snapshots y limpieza automática.
*   **[Capítulo 07: Configuración de GRUB](docs/Capítulo-07-Configuración-de-GRUB.md)** - Configuración del gestor de arranque e integración con `grub-btrfs`.
*   **[Capítulo 08: mkinitcpio](docs/Capítulo-08-mkinitcpio.md)** - Creación del initramfs adaptado a BTRFS.
*   **[Capítulo 09: Verificación de Snapshots](docs/Capítulo-09-Verificacion-de-Snapshots.md)** - Validación inicial del funcionamiento de las capturas del sistema.
*   **[Capítulo 10: Primer Arranque](docs/Capítulo-10-Primer-arranque.md)** - Retirada del Live USB y validación del sistema en caliente.
*   **[Capítulo 11: Rollback (Revertir el sistema)](docs/Capítulo-11-Rollback.md)** - Procedimiento paso a paso para restaurar un snapshot anterior en caso de desastre.

### 🎨 Parte II: Entornos de Escritorio (Dotfiles & Configuración)

#### Sección A: Hyprland (Wayland - Moderno)
*   **[Capítulo 12: Instalación de Hyprland](docs/Capítulo-12-Instalacion-Hyprland.md)** - Instalación del compositor y de los paquetes requeridos.
*   **[Capítulo 13: Configuración de Waybar](docs/Capítulo-13-Configuracion-Waybar.md)** - Personalización del panel superior de Hyprland.
*   **[Capítulo 14: Uso de Hyprland](docs/Capítulo-14-Uso-Hyprland.md)** - Atajos de teclado esenciales, atajos rápidos y workflow en Wayland.

#### Sección B: Qtile (X11 - Compatible)
*   **[Capítulo 19: Instalación y Uso de Qtile](docs/Capítulo-19-Instalacion-y-Uso-de-Qtile.md)** - Configuración de Qtile, layouts, shortcuts (`Super + A` para audio) y multimonitor en X11.

### 🛠️ Parte III: Herramientas, Administración y Gaming
*   **[Capítulo 15: Gestión de Paquetes](docs/Capítulo-15-Gestion-Paquetes.md)** - Buenas prácticas en el uso de `pacman` y `paru` en CachyOS.
*   **[Capítulo 16: Acceso Remoto Seguro](docs/Capítulo-16-Acceso-Remoto.md)** - Configuración del servidor SSH seguro.
*   **[Capítulo 17: Herramientas CLI Modernas](docs/Capítulo-17-Herramientas-CLI-modernas.md)** - Uso de utilidades de productividad en consola (btop, fastfetch, etc.).
*   **[Capítulo 18: Optimización de Gaming](docs/Capítulo-18-Gaming.md)** - Configuración de Steam, GameMode, MangoHud y Proton-GE.

---

## Licencia

Este proyecto está licenciado bajo los términos de la **GNU Affero General Public License v3.0**.
Ver el archivo [LICENSE](LICENSE) para más detalles.


