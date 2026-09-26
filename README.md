# Instalador de CachyOS (Automatizado y Modular)

![Estado](https://img.shields.io/badge/estado-Operativo-orange)
![Stack](https://img.shields.io/badge/stack-Bash%20%7C%20BTRFS%20%7C%20Arch-informational)

Scripts de instalación automatizada para **CachyOS** con BTRFS, snapshots Snapper y entornos gráficos Hyprland (Wayland) y Qtile (X11). 

Desarrollados y validados en hardware real como complemento del manual técnico completo disponible en **[humanbyte.net](https://humanbyte.net/manuales/de-gentoo-a-cachyos/)**.

---

## 🚀 Instalación Rápida

```bash
# Paso 1 — desde el Live USB de CachyOS (como root, con internet activo)
pacman -Sy --noconfirm git
git clone https://github.com/terracenter/cachyos-install.git /tmp/cachyos-install
cd /tmp/cachyos-install
sudo ./install.sh
```

Una vez terminada la fase base, **reinicia** la máquina, entra con tu usuario nuevo y corre lo siguiente:

```bash
# Paso 2 — ya en tu sistema instalado (como usuario normal)
git clone https://github.com/terracenter/cachyos-install.git ~/cachyos-install
cd ~/cachyos-install
./install.sh
```

---

## 📂 Nueva Estructura Modular (Basada en Omarchy)

Ahora el entorno **Hyprland** está diseñado con una arquitectura 100% modular, limpia y sin paquetes basura (bloatware). Usamos orquestadores que cargan pequeños módulos (leaves) directamente desde una carpeta interna:

```
cachyos-install/
├── install.sh                        ← Menú principal interactivo
├── README.md
├── LICENSE
├── base/
│   └── install-base.sh               (Sistema base: BTRFS, GRUB, Snapper)
├── hyprland/
│   ├── install-hyprland-desktop.sh   ← Orquestador Base (núcleo y config de sistema)
│   ├── install-hyprland-apps.sh      ← Orquestador de Aplicaciones (Chrome, Gaming, Dev)
│   ├── check-omarchy-updates.sh      ← Script para jalar novedades del upstream (Omarchy)
│   ├── install/                      ← (Módulos hoja sourceables, sin shebangs)
│   └── themes/                       (Temas de colores Catppuccin, Nord, etc.)
├── qtile/
│   ├── install-qtile-omarchy.sh      (Entorno Qtile X11)
│   └── configs/                      
└── docs/                             (Documentación técnica y manuales)
```

---

## 🛠️ Herramientas de Monitoreo (Upstream)

Si quieres ver si hay algo nuevo en el proyecto Omarchy para integrarlo a nuestro instalador, entra a `hyprland/` y corre el script de monitoreo:
```bash
./check-omarchy-updates.sh
```

---

## 🛡️ Seguridad y Redes

A diferencia de la versión original de Omarchy que usa UFW, nuestra versión implementa un **firewall nftables no monolítico**, clonando e integrando las reglas robustas del proyecto `firewall-nftable`.

---

## 📖 Manual Completo y Referencias

El handbook técnico detallado está en la carpeta `docs/`.
