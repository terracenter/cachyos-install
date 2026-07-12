# 🚀 De Gentoo a CachyOS: Handbook Completo y Scripts de Instalación

¡El manual técnico completo y los scripts de automatización han sido migrados a su repositorio oficial en GitHub!

Para ofrecer un mantenimiento óptimo, control de versiones comunitario y recibir contribuciones de la comunidad Linux, toda la documentación detallada (los 18 capítulos del handbook) y el código de instalación ahora residen en:

👉 **[GitHub: terracenter/cachyos-install](https://github.com/terracenter/cachyos-install)**

## 📦 ¿Qué incluye el repositorio?

El repositorio contiene el ecosistema completo para desplegar una instalación limpia y ultra-optimizada de CachyOS:

*   **Fase 1 (Sistema Base):** Particionado BTRFS con subvolúmenes dinámicos optimizados para NVMe, despliegue de sistema base (`pacstrap`), hooks de recuperación del kernel, GRUB con soporte automático para arrancar snapshots de Snapper (`grub-btrfs`) y configuraciones de redundancia.
*   **Fase 2 (Escritorio y Productividad):**
    *   **Hyprland (Wayland):** Entorno moderno con Waybar, control de energía integrado y tematización dinámica Catppuccin Mocha (estilo Omarchy).
    *   **Qtile (X11):** Configuración robusta de Qtile con soporte multi-monitor inteligente, atajos rápidos y nuestro nuevo **selector de salida de audio integrado con Rofi (`Super + A`)** que detecta y corrige automáticamente perfiles físicos y auriculares en laptops.
*   **Fase 3 (Gaming Stack):** Configuración automática de Steam, GameMode, MangoHud y Proton-GE para máximo rendimiento de FPS.
*   **Documentación Completa:** El manual detallado paso a paso para realizar la instalación manual o comprender la lógica detrás de cada script (disponible en la carpeta `gentoo-a-cachyos-y-lvm-a-btrfs/` del repositorio).

## 🛠️ Instalación Rápida

Puedes iniciar el proceso directamente desde el Live USB oficial de CachyOS:

```bash
# Ejecutar Fase 1 (Desde el Live USB - requiere root)
curl -fsSL https://raw.githubusercontent.com/terracenter/cachyos-install/main/bootstrap.sh | sudo bash
```

Una vez finalizado, reinicia y ejecuta la Fase 2 (como usuario normal):

```bash
# Ejecutar Fase 2 (Sistema instalado - usuario normal)
curl -fsSL https://raw.githubusercontent.com/terracenter/cachyos-install/main/bootstrap-desktop.sh | bash
```

---

> [!TIP]
> Si deseas contribuir con mejoras en las configuraciones de Qtile, Hyprland o reportar algún inconveniente con el audio en hardware específico, siéntete libre de abrir un **Pull Request** o **Issue** en el repositorio.
