← [Cap. 18 — Gaming](Capítulo-18-Gaming.md) · [Índice](_index.md)

---

## Introducción

Este capítulo documenta la instalación, configuración y uso del entorno gráfico alternativo **Qtile** sobre el servidor X11, personalizado con el diseño visual **Omarchy**. 

Qtile representa la alternativa a Hyprland (Wayland) en este repositorio, proveyendo un entorno de ventanas en mosaico (tiling) altamente configurable en Python puro.

---

## 1. Procedimiento de Instalación

La instalación se realiza a través de la herramienta unificada `install-qtile-omarchy.sh`, ubicada en el repositorio `terracenter/cachyos-install`. 

### Ejecución del instalador
Para realizar la instalación en limpio o actualizar la existente, se ejecuta desde la terminal del usuario:
```bash
bash install-qtile-omarchy.sh
```

### Qué realiza el script de instalación:
1. **Verificación de dependencias base**: Instala paquetes críticos de la sesión X11 (`xorg-server`, `qtile`, `python-psutil`) y cosméticos (`rofi`, `alacritty`, `pamixer`, `brightnessctl`, `shutter`, `xclip`, `rofi-greenclip`, `dunst`).
2. **Instalación de Eww (Sysmon)**: Instala y compila la hoja de estilos de Eww con `dart-sass` para que cargue los colores de temas dinámicos.
3. **Gestión de Energía (TLP) Inteligente**:
   * Si detecta que es una **Laptop**, instala `tlp` / `tlpui` y habilita el servicio de ahorro de batería (`tlp.service`).
   * Si es una **Desktop (Escritorio)**, omite la instalación para evitar problemas de suspensión de dispositivos USB.
4. **Descansos Obligatorios (Safe Eyes)**: Instala `safeeyes` para automatizar las pausas obligatorias y prevenir fatiga visual.
5. **Copia de Configuraciones**: Mueve las plantillas y archivos dotfiles de Qtile (`config.py`), lanzadores y scripts de monitores/teclados a `~/.config/qtile/` y `~/.local/bin/`.
6. **Resolución de Conflictos SDDM**: Elimina la sesión Wayland por defecto de Qtile (`qtile-wayland.desktop`) para evitar que SDDM entre en bucle de login (login loop) por falta de dependencias de Wayland.

---

## 2. Combinaciones de Teclas (Keybindings)

La tecla modificadora principal es **Super** (tecla Windows).

### Aplicaciones y Utilidades

| Combinación | Acción |
|---|---|
| `Super + Q` | Abrir terminal (`alacritty`) |
| `Super + E` | Abrir gestor de archivos (`nautilus`) |
| `Super + Space` | Abrir lanzador de apps (`rofi`) |
| `Super + Ctrl + V` | Historial de portapapeles (`rofi-greenclip`) |
| `Super + Ctrl + T` | Monitor de actividad (`btop` en terminal) |
| `Super + Shift + T` | Selector de temas Omarchy (`theme-switcher`) |
| `Super + Ctrl + M` | Configuración gráfica de monitores (`qtile-monitor-setup`) |
| `Super + K` | Configuración de distribución de teclado (`qtile-keyboard-setup`) |
| `Super + Print` | Captura de pantalla interactiva al portapapeles (`shutter`) |
| `Super + Shift + Q` | Menú visual de apagado/cierre de sesión (`qtile-exit`) |
| `Super + M` | Menú visual de apagado/cierre de sesión (`qtile-exit`) |

### Gestión y Foco de Ventanas

| Combinación | Acción |
|---|---|
| `Super + Shift + W` | Cerrar ventana activa |
| `Super + T` | Alternar ventana entre flotante / mosaico (tiling) |
| `Super + F` | Pantalla completa |
| `Super + Shift + Y` | Rotar entre layouts (`MonadTall`, `MonadWide`, `Max`, `Bsp`, `Columns`) |
| `Super + ← / → / ↑ / ↓` | Mover el foco en la dirección correspondiente |
| `Super + Shift + ← / → / ↑ / ↓` | Mover la ventana activa en la dirección correspondiente |
| `Super + Ctrl + ← / → / ↑ / ↓` | Redimensionar la ventana activa |

---

## 3. Interactividad de la Barra y cuidado de la salud

La barra superior de Qtile incorpora widgets dinámicos altamente interactivos:

### 🔊 Volumen
* **Indicación**: Muestra el porcentaje y estado del volumen general mediante `pamixer`.
* **Clic Izquierdo**: Abre el panel de control gráfico de audio (`pavucontrol`).
* **Clic Derecho**: Alterna entre silencio (mute/unmute).
* **Scroll (Rueda)**: Sube o baja el volumen en pasos de 5%.

### 󰖨 Brillo (Laptops)
* **Indicación**: Muestra el porcentaje actual de brillo.
* **Scroll (Rueda)**: Regula de forma sincronizada el brillo físico de tu laptop (`brightnessctl`) y de tu monitor externo HDMI-1 (`xrandr --brightness`), guardando el estado en caché.

### 󰖔 Luz Nocturna (Redshift)
* **Indicación**: Muestra un sol (`󰛨 `) cuando está inactiva y una luna (`󰖔 `) cuando está activa.
* **Clic Izquierdo**: Activa/desactiva la luz nocturna.
  * **Modo Automático**: Al encenderse, hace una consulta ligera a un servicio de IP Geolocation (`ip-api.com`) para saber exactamente si estás en Naguanagua, Margarita o Caracas y aplicar las coordenadas solares reales, cayendo en fallback a Caracas si no hay red.
  * **Throttling**: Bloquea clicks rápidos repetidos para prevenir que se spawneen procesos múltiples que pongan la pantalla totalmente anaranja o crasheen el servidor de color.

### 🔋 Batería (Laptops)
* **Indicación**: Carga de batería e icono representativo de estado.
* **Clic Izquierdo**: Envía una notificación del sistema limpia (`notify-send`) con el estado exacto de carga e información del sensor.

---

## 4. Menú de Sesión, Bloqueo de Pantalla y Descansos

* **Menú de Sesión (`Super + Shift + Q`)**: Lanza la utilidad `qtile-exit`, que despliega un menú Rofi con las siguientes opciones:
  - **Cancelar**: Vuelve al escritorio (opción por defecto).
  - **Bloquear**: Bloquea la pantalla inmediatamente usando `qtile-lock`.
  - **Suspender**: Coloca la laptop/desktop en estado de suspensión (`systemctl suspend`).
  - **Salir**: Cierra de forma limpia la sesión de Qtile (`qtile cmd-obj -o cmd -f shutdown`).
  - **Reiniciar**: Reinicia el equipo (`systemctl reboot`).
  - **Apagar**: Apaga el sistema (`systemctl poweroff`).
* **Bloqueo Manual**: En cualquier momento se puede bloquear la pantalla presionando **`Super + Ctrl + L`**. Esto invoca al wrapper `qtile-lock` que lee la paleta del tema dinámico y aplica un bloqueo elegante difuminado con reloj mediante `i3lock-color`.
* **Descansos Obligatorios (Safe Eyes)**: Safe Eyes corre en la bandeja de sistema (`system tray`) y te alertará visualmente antes de iniciar las pausas. Durante los descansos largos, bloqueará la pantalla con una cuenta regresiva. Cuenta con botones interactivos que permiten **posponer** o **saltar** el descanso si te encuentras realizando alguna actividad crítica.

---

← [Cap. 18 — Gaming](Capítulo-18-Gaming.md) · [Índice](_index.md)
