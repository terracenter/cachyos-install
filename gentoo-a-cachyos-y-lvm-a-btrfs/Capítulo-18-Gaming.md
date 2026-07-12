← [Cap. 17 — Herramientas CLI modernas](Capítulo-17-Herramientas-CLI-modernas.md) · [Índice](..) · [Cap. 19 — Instalación y Uso de Qtile](Capítulo-19-Instalacion-y-Uso-de-Qtile.md) →

---

## Para el purista 64-bit: por qué lib32 en gaming no es lo que piensas

Si llevas años en Linux evitando multilib porque no quieres basura 32-bit en tu sistema, esta sección es para ti. Yo pensé lo mismo — hasta que entendí qué es exactamente lo que se instala.

### El mito: "habilitar multilib ensucia el sistema"

Multilib es simplemente un **repositorio adicional de pacman**. Habilitarlo no instala nada por sí solo. Lo que determina qué entra al sistema es qué paquetes le pides explícitamente a pacman.

### La realidad: 8 paquetes lib32, específicos y declarados

Para gaming con Steam + Proton, lo que realmente necesitas es esto (ejemplo con GPU AMD):

```
lib32-glibc              — libc estándar, versión 32-bit
lib32-gcc-libs           — runtime de GCC, versión 32-bit
lib32-vulkan-icd-loader  — dispatcher de Vulkan para apps 32-bit
lib32-mesa               — drivers OpenGL/Vulkan 32-bit (AMD/Intel)
lib32-vulkan-radeon      — driver Vulkan específico AMD 32-bit
lib32-gamemode           — soporte GameMode para juegos 32-bit
lib32-mangohud           — overlay MangoHud para juegos 32-bit
```

Total: 7-8 paquetes declarados. No corren servicios en background. No modifican el comportamiento del sistema. Son **librerías pasivas** que Wine/Proton carga cuando lanzas un juego y descarga cuando lo cierras.

Puedes verificar en cualquier momento exactamente qué lib32 tiene el sistema:

```bash
pacman -Q | grep '^lib32-'
```

### ¿Por qué los necesita Wine/Proton?

Un juego de Windows como Microsoft Flight Simulator 2024 es un ejecutable 64-bit. Pero Proton (la capa de traducción que lo hace correr en Linux) tiene componentes internos que son 32-bit — específicamente partes del servidor de Wine y algunas capas de compatibilidad DirectX. Estos componentes necesitan las librerías 32-bit del sistema operativo para funcionar.

Sin lib32, Proton no puede inicializar esos componentes y el juego falla al lanzar.

### Flatpak hacía lo mismo, pero escondido

La configuración anterior usaba Flatpak para Steam. Lo que Flatpak hacía internamente era exactamente esto: bundlear lib32 dentro de su contenedor. La diferencia es que con Flatpak no veías los paquetes lib32 en `pacman -Q` — estaban ocultos dentro del runtime de Flatpak en `~/.var/`.

Con la configuración de este capítulo, los paquetes son **explícitos, declarados y auditables**. Sabes exactamente qué 32-bit hay en tu sistema porque tú lo instalaste con pacman.

---

## Instalación

El script de gaming se instala en un sistema ya configurado, donde el usuario normal ya tiene acceso SSH. Se copia directamente al home del usuario — no a `/root/`.

Desde tu workstation:

```bash
scp install-gaming.sh USUARIO@IP_DEL_EQUIPO:
```

En el equipo destino:

```bash
ssh USUARIO@IP_DEL_EQUIPO
bash ~/install-gaming.sh
```

El script presenta un menú de componentes opcionales antes de instalar.

---

## Componentes base (siempre instalados)

| Componente | Fuente | Tipo | Función |
|---|---|---|---|
| multilib | repo | Repositorio | Habilita paquetes lib32 en pacman |
| lib32-* (7-8 paquetes) | multilib | Librerías | Soporte 32-bit para Wine/Proton |
| Steam | multilib | App nativa | Plataforma principal de juegos |
| GameMode | CachyOS repos | App nativa 64-bit | Optimiza CPU/GPU automáticamente al jugar |
| MangoHud | CachyOS repos | App nativa 64-bit | Overlay de FPS, temperatura y uso de recursos |

---

## Componentes opcionales

| Herramienta | Fuente | Para qué sirve | Recomendado |
|---|---|---|---|
| **ProtonUp-Qt** | AUR (Qt nativo) | Gestiona versiones de Proton-GE dentro de Steam | Siempre |
| **Lutris** | AUR (Python nativo) | Panel unificado para Epic, GOG, itch.io, emuladores | Si tienes Epic o GOG |
| **Wine Staging** | repos | Ejecutar .exe directamente sin Steam ni Lutris | Usuarios avanzados / juegos viejos |

### ProtonUp-Qt — recomendado para todos

**Proton-GE** es un fork comunitario de Proton con más parches, más codecs y mejor compatibilidad que el Proton oficial que incluye Steam. ProtonUp-Qt es la herramienta gráfica que instala y actualiza Proton-GE dentro de Steam.

ProtonUp-Qt es un **paquete AUR nativo en Qt** — no es Flatpak, no es AppImage. Se instala con paru y queda como cualquier otro ejecutable del sistema.

**Flujo de uso:**
1. Abre ProtonUp-Qt desde rofi
2. Selecciona Steam como destino
3. Clic en "Add version" → GE-Proton → instala la última versión
4. En Steam → Configuración → Compatibilidad → activar Proton → seleccionar GE-Proton

### Lutris — para juegos fuera de Steam

Lutris es una aplicación **Python/GTK nativa** que unifica en un solo panel Steam, Epic Games, GOG, itch.io, Humble Bundle, emuladores y juegos instalados manualmente.

Descarga sus propios runners de Wine/Proton en `~/.local/share/lutris/runners/` — no depende del Wine del sistema para ejecutar juegos. Tiene scripts de instalación mantenidos por la comunidad para miles de juegos y aplicaciones Windows.

**Flujo de uso básico para Epic Games:**
1. Abre Lutris desde rofi
2. Conecta tu cuenta Epic en Preferencias → Fuentes → Epic Games Store
3. Tu biblioteca aparece automáticamente
4. Instala y lanza desde Lutris

### Wine Staging — para .exe directos y juegos legacy

`wine-staging` es la versión de Wine con parches adicionales de rendimiento y compatibilidad. Útil para:
- Juegos viejos que no tienen plataforma (Delta Force 1999, simuladores de los 2000)
- Aplicaciones Windows que necesitas correr sin Steam ni Lutris
- Pruebas y debugging de compatibilidad

Se instala junto con `winetricks`, una herramienta para gestionar prefijos de Wine e instalar dependencias Windows (DirectX runtimes, VCRedist, etc.).

---

## GameMode

**GameMode** es un daemon de Feral Interactive que optimiza el sistema automáticamente cuando un juego está activo:

| Optimización | Descripción |
|---|---|
| Gobernador de CPU | Cambia a `performance` durante la sesión de juego |
| Prioridad de proceso | Aumenta la prioridad del proceso del juego |
| GPU hints | Envía señales de rendimiento al driver (AMD/NVIDIA) |
| Inhibición de suspensión | Evita que el sistema suspenda durante el juego |

Al terminar el juego, revierte todos los cambios automáticamente.

### Verificación

```bash
gamemoded -t
```

```
: Testing GameMode, good luck!
: sched_getaffinity scheduler policy is SCHED_OTHER
...
: Status: GameMode is ready.
```

### Activar en Steam

En las propiedades de cada juego → Opciones de lanzamiento:

```
gamemoderun %command%
```

---

## MangoHud

**MangoHud** muestra un overlay configurable con métricas de rendimiento en tiempo real.

### Configuración base

El script crea `~/.config/MangoHud/MangoHud.conf` con:

| Métrica | Descripción |
|---|---|
| FPS | Fotogramas por segundo |
| GPU stats | Porcentaje de uso de GPU |
| GPU temp | Temperatura de GPU en °C |
| GPU name | Nombre de la GPU detectada |
| CPU stats | Porcentaje de uso de CPU |
| CPU temp | Temperatura de CPU en °C |
| RAM / VRAM | Memoria RAM y de vídeo usada |

### Activar en Steam

```
MANGOHUD=1 %command%
```

### Combinación recomendada (GameMode + MangoHud)

```
MANGOHUD=1 gamemoderun %command%
```

---

## GPU Intel Iris Xe — Configuración y monitoreo

La GPU integrada Intel Iris Xe (Tiger Lake) funciona con los drivers `mesa` + `lib32-vulkan-intel` instalados por el script base. No requiere variables de entorno adicionales para uso general.

### Monitoreo durante el juego

`intel-gpu-tools` (instalado junto con conky en el script de escritorio) incluye `intel_gpu_top`. Para monitoreo manual durante una sesión de juego:

```bash
sudo intel_gpu_top -s 3000 -c
```

Las columnas relevantes:

| Columna | Significado |
|---|---|
| `Freq MHz act` | Frecuencia real de la GPU |
| `RC6 %` | Tiempo en reposo — debe ser 0% durante el juego |
| `Power W gpu` | Consumo de la GPU en vatios |
| `Power W pkg` | Consumo del paquete CPU+GPU |
| `RCS %` | Uso del engine Render/3D |

### Valores de referencia — Lenovo IdeaPad 3 14ITL6 (Tiger Lake, CachyOS)

**Escritorio Hyprland en idle:**

| Métrica | Valor |
|---|---|
| Frecuencia | 100–130 MHz |
| RC6 | 70–75% |
| Render/3D | 24–26% (compositor Wayland) |
| Potencia GPU | 0.5–0.6 W |
| Potencia Package | 6–8 W |

**Durante juego (X-Plane 12, Vulkan):**

| Métrica | Valor | Interpretación |
|---|---|---|
| Frecuencia | 1292–1295 MHz | 99% del máximo de 1300 MHz — sin throttling |
| RC6 | 0% | GPU completamente activa |
| Render/3D | ~100% | GPU es el cuello de botella (normal en simuladores) |
| Potencia GPU | 12–16 W | Consumo máximo normal para Iris Xe |
| Potencia Package | 18–20 W | Dentro del TDP del Tiger Lake |

### Detectar throttling térmico

El throttling se manifiesta como **frecuencia cayendo progresivamente** mientras el uso (RCS) sigue al 100%. Si `Freq MHz act` baja de ~1290 MHz hacia 500–300 MHz sin razón aparente, el SoC está limitando por temperatura.

Pasos ante throttling:
1. Verificar que GameMode está activo: `gamemoded -t`
2. Revisar ventilación física del equipo
3. Reducir carga gráfica en los ajustes del juego

---

## Microsoft Flight Simulator en Linux

MSFS 2020 y 2024 funcionan en Linux vía Proton-GE. No es instalación directa — requiere configuración específica.

**Requisitos:**
- Steam instalado con Proton-GE (vía ProtonUp-Qt)
- MSFS comprado en Steam (la versión Microsoft Store no funciona vía Proton)

**Configuración:**
1. En Steam, busca MSFS y habilita Proton en sus propiedades
2. Selecciona GE-Proton (última versión) como versión de compatibilidad
3. Opciones de lanzamiento recomendadas:

```
MANGOHUD=1 gamemoderun %command%
```

4. Primera instalación: MSFS descarga ~150 GB de contenido — puede tardar horas
5. Si el lanzador interno falla, consulta ProtonDB para la versión específica de GE-Proton que funciona mejor con la build actual del juego

**ProtonDB:** [protondb.com](https://www.protondb.com) — busca "Microsoft Flight Simulator" para ver los reportes actuales de la comunidad, versión de Proton usada y tweaks necesarios.

---

## X-Plane 12 en Linux

X-Plane 12 es nativo en Linux — no requiere Proton ni capas de traducción. Se instala directamente desde Steam.

**Configuración validada en Intel Iris Xe (Lenovo IdeaPad 3 14ITL6, CachyOS).**

### Opciones de lanzamiento en Steam

En las propiedades del juego → Opciones de lanzamiento:

```
MANGOHUD=1 gamemoderun %command%
```

### Configuración dentro del juego

Menú: **Settings → Graphics**

| Opción | Valor | Motivo |
|---|---|---|
| Resolution | **Window mode** | Full mode es fullscreen exclusivo — causa pantalla negra en Hyprland |
| Limit Frame Rate | **60 fps** | Iris Xe no puede sostener 120/144 fps en un simulador de vuelo |
| 3D Graphics API | **Vulkan** | Driver ANV de Mesa; mejor rendimiento y menor CPU overhead que OpenGL en Intel Linux |
| High Quality Anti-Aliasing | **Desactivar** | Muy costoso para GPU integrada |
| Lens Flare Effect | **Desactivar** | Cosmético — carga innecesaria |
| Brighten Night Color | A gusto | Sin impacto en rendimiento |
| Brighten Aircraft Interior | A gusto | Sin impacto en rendimiento |

**Ajustes adicionales de rendimiento (Rendering Options):**

| Opción | Valor recomendado |
|---|---|
| Volumetric Clouds | **Low** — mayor impacto individual en rendimiento |
| Shadows | Medium |
| Texture Resolution | Medium (evitar High — consume VRAM compartida con la RAM) |
| Terrain Level of Detail | 50–80 |
| Object Level of Detail | 50 |

### Comportamiento de la GPU con esta configuración

Con los ajustes anteriores, el Iris Xe trabaja al límite de su capacidad. Esto es **normal y esperado** en un simulador de vuelo con GPU integrada:

- **RCS 100%:** la GPU es el cuello de botella, no la CPU
- **Frecuencia ~1293 MHz estable:** sin throttling térmico
- **RC6 0%:** GPU completamente activa, sin estados de reposo
- **Potencia Package 18–20 W:** dentro del TDP del Tiger Lake (~28 W)

Si los FPS caen por debajo de 30, el ajuste con mayor impacto es bajar **Volumetric Clouds a Low**.

---

## Compatibilidad de juegos sin lib32 del sistema

Con esta configuración los juegos compatibles son:

| Tipo | Funciona | Ejemplos |
|---|---|---|
| Juego nativo Linux 64-bit | Siempre | CS2, Dota 2, TF2, Assetto Corsa, BeamNG.drive |
| Juego Windows 64-bit vía Proton | Sí | MSFS 2024, Halo MCC, simuladores modernos |
| Juego Windows 32-bit vía Wine | Sí (con lib32-mesa/vulkan) | Delta Force 1999, simuladores legacy |
| Juego con anti-cheat EAC/BattleEye | Depende | Algunos funciona, otros no |
| Juego con anti-cheat NProtect/Vanguard | No | Delta Force (2024 remake), Valorant |

**Nota sobre Delta Force:** El juego original de 1999 (NovaLogic) funciona con Wine Staging. El remake de 2024 (Nexon) usa NProtect GameGuard y no es compatible con Linux.

---

## Verificar compatibilidad antes de comprar

- [ProtonDB](https://www.protondb.com) — reportes de la comunidad sobre compatibilidad con Proton
- Calificación "Platinum" u "Gold" = funciona sin configuración adicional
- Calificación "Silver" = funciona con ajustes documentados en la página del juego
- Calificación "Borked" = no funciona actualmente

---

## Solución de problemas

### Pantalla negra al presionar Escape o cambiar de modo

**Síntoma:** el juego se congela con pantalla negra al presionar Escape, Alt+Enter, o al intentar minimizar. El proceso del juego sigue activo pero el escritorio no recupera la imagen.

**Causa:** la mayoría de juegos nativos Linux y los que corren bajo XWayland usan fullscreen exclusivo — toman control directo del framebuffer. En Wayland/Hyprland, cuando el juego intenta salir de ese modo (al abrir un menú, minimizar o cambiar resolución), el compositor no siempre reconstruye la superficie correctamente y la pantalla queda negra.

**Solución:** cambiar el modo de pantalla del juego de **Fullscreen** a **Windowed** o **Borderless Windowed** en la configuración de video/gráficos del propio juego. Con borderless, el compositor mantiene el control de la pantalla en todo momento y el problema desaparece.

Si el juego quedó colgado y no responde:

```bash
pkill -f nombre_del_proceso
```

Luego relanza el juego y cambia el modo de pantalla antes de entrar a jugar.

---

## Configuraciones validadas por hardware

Esta sección se amplía conforme se prueban juegos en nuevos equipos. Cada juego documenta los ajustes validados para el hardware específico donde fue probado.

| Equipo | GPU | Sistema | Estado |
|---|---|---|---|
| Lenovo IdeaPad 3 14ITL6 | Intel Iris Xe (Tiger Lake) | CachyOS + Hyprland | Documentado |
| Mini PC (pendiente) | AMD (ATI) | Por definir | Pendiente de validación |

Cuando se validen juegos en el mini PC con GPU AMD, se añadirán subsecciones con los ajustes específicos de ese hardware — incluyendo las variables de entorno relevantes para Mesa/RADV y los valores de referencia de `radeontop` o equivalente.

---

← [Cap. 17 — Herramientas CLI modernas](Capítulo-17-Herramientas-CLI-modernas.md) · [Índice](..) · [Cap. 19 — Instalación y Uso de Qtile](Capítulo-19-Instalacion-y-Uso-de-Qtile.md) →
