← [Cap. 15 — Gestión de paquetes](Capítulo-15-Gestion-Paquetes.md) · [Índice](..) · [Cap. 17 — Herramientas CLI modernas](Capítulo-17-Herramientas-CLI-modernas.md) →

---

## Introducción

Este capítulo documenta las herramientas de acceso remoto disponibles en la instalación CachyOS + Hyprland, tanto para controlar equipos remotos como para recibir conexiones entrantes.

| Herramienta | Rol | Protocolo |
|---|---|---|
| SSH | Administración CLI | SSH |
| wayvnc | Servidor — recibir conexiones al escritorio Hyprland | VNC sobre túnel SSH |
| AnyDesk | Cliente — conectarse a equipos remotos | AnyDesk |
| TigerVNC viewer | Cliente — conectarse a servidores VNC remotos | VNC |

---

## wayvnc — servidor VNC nativo Wayland

`wayvnc` es el servidor VNC nativo para Wayland. Permite controlar el escritorio Hyprland desde otro equipo.

### Por qué no usar VNC directo

Exponer el puerto VNC directamente en la red es inseguro — el tráfico no está cifrado. La solución es combinar wayvnc con un túnel SSH:

- wayvnc escucha solo en `127.0.0.1` — no accesible desde la red
- El túnel SSH cifra todo el tráfico
- La autenticación usa las credenciales del sistema (PAM)

### Instalación

```bash
paru -S wayvnc
```

### Configuración del autostart

wayvnc se agrega al autostart de `~/.config/hypr/hyprland.lua` para arrancar automáticamente con la sesión Hyprland:

```lua
hl.exec_cmd("uwsm app -- wayvnc --render-cursor 127.0.0.1 5900")
```

> `--render-cursor` dibuja el cursor dentro del frame de pantalla para que sea visible en el cliente VNC. Sin esta opción el cursor no aparece en la sesión remota.

### Verificar que está corriendo

```bash
pgrep -a wayvnc
ss -tlnp | grep 5900
```

### Inicio manual (si no arrancó con la sesión)

wayvnc necesita el entorno Wayland activo. Desde una terminal en Hyprland:

```bash
wayvnc --render-cursor 127.0.0.1 5900 &
```

---

## Conectarse al laptop desde otro equipo

### Requisitos en el equipo cliente

- SSH instalado
- TigerVNC viewer: `sudo pacman -S tigervnc` (Arch) o equivalente

### Paso 1 — Crear el túnel SSH

Abrir una terminal y dejarla abierta durante toda la sesión remota:

```bash
ssh -L 5901:localhost:5900 -N USUARIO@IP_DEL_EQUIPO
```

| Parámetro | Descripción |
|---|---|
| `-L 5901:localhost:5900` | Reenvía el puerto local 5901 al puerto 5900 del laptop |
| `-N` | No ejecuta comandos — mantiene el túnel activo |
| `USUARIO@IP_DEL_EQUIPO` | Usuario y dirección del laptop |

El terminal queda "bloqueado" — es el comportamiento correcto. El túnel está activo mientras ese terminal esté abierto.

### Paso 2 — Conectar con TigerVNC

En otra terminal:

```bash
vncviewer -PreferredEncoding=Tight -QualityLevel=7 localhost:5901
```

| Opción | Descripción |
|---|---|
| `-PreferredEncoding=Tight` | Mejor compresión para conexiones lentas o WiFi |
| `-QualityLevel=7` | Balance entre calidad y fluidez (rango 0–9) |

> Conectar a `localhost:5901` — el túnel reenvía al laptop automáticamente.

---

## AnyDesk — cliente para conectarse a equipos remotos

AnyDesk funciona correctamente en Hyprland como **cliente** para conectarse a otros equipos que lo tengan instalado.

```bash
paru -S anydesk
sudo systemctl enable --now anydesk
```

> AnyDesk como **servidor** (para recibir conexiones) no funciona de forma fiable en Wayland. Usar wayvnc + túnel SSH para ese caso.

---

## TigerVNC viewer — cliente VNC

Para conectarse a servidores VNC en otros equipos (Linux con X11, Windows, etc.):

```bash
vncviewer IP_REMOTA:5900
```

Con mejores opciones de rendimiento:

```bash
vncviewer -PreferredEncoding=Tight -QualityLevel=7 IP_REMOTA:5900
```

---

## Resumen de conexión rápida

```bash
# Túnel SSH (dejar abierto)
ssh -L 5901:localhost:5900 -N USUARIO@IP_DEL_EQUIPO

# Conectar VNC (en otra terminal)
vncviewer -PreferredEncoding=Tight -QualityLevel=7 localhost:5901
```

---

← [Cap. 15 — Gestión de paquetes](Capítulo-15-Gestion-Paquetes.md) · [Índice](..) · [Cap. 17 — Herramientas CLI modernas](Capítulo-17-Herramientas-CLI-modernas.md) →
