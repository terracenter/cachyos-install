# Capítulo 18: Gaming en CachyOS

[← Cap. 17: Herramientas CLI](Capítulo-17-Herramientas-CLI-modernas.md) · [Índice](./_index.md) · [Cap. 19: Qtile →](Capítulo-19-Instalacion-y-Uso-de-Qtile.md)

## Alcance

La configuración de gaming es opcional y depende de la GPU, sus drivers, Vulkan, bibliotecas de 32 bits y cada juego. Las optimizaciones de software no garantizan incrementos importantes de FPS.

Antes de instalar launchers o herramientas, valida la GPU y el driver.

## Detectar hardware gráfico

```bash
lspci -k | grep -EA3 'VGA|3D|Display'
```

Comprueba OpenGL:

```bash
glxinfo -B
```

Comprueba Vulkan:

```bash
vulkaninfo --summary
```

En equipos híbridos, identifica cuál GPU renderiza por defecto y cuál debe utilizarse para juegos.

## Drivers y bibliotecas

No instales una lista universal de paquetes gráficos.

### Intel

Normalmente utiliza Mesa y el driver Vulkan de Intel. Las bibliotecas de 32 bits deben corresponder a la misma familia usada por Steam y Wine.

### AMD

Normalmente utiliza Mesa, RADV y sus bibliotecas de 32 bits.

### NVIDIA

El paquete debe corresponder al kernel y al modelo soportado. Comprueba que el módulo esté cargado y que Vulkan detecte la GPU.

### Verificación

```bash
pacman -Q | grep -E 'mesa|vulkan|nvidia'
```

No mezcles drivers de distintas familias sin una configuración híbrida real.

## Metapaquetes de CachyOS

CachyOS ofrece metapaquetes que agrupan bibliotecas y aplicaciones de gaming. Antes de instalarlos, revisa su contenido:

```bash
pacman -Si cachyos-gaming-meta
```

```bash
pacman -Si cachyos-gaming-applications
```

Instala solo lo necesario:

```bash
sudo pacman -S cachyos-gaming-meta
```

El metapaquete de aplicaciones puede incluir launchers y herramientas que no todos los equipos necesitan.

## Steam y Proton

Instala Steam desde los repositorios configurados:

```bash
sudo pacman -S steam
```

Activa Steam Play desde la configuración de Steam cuando necesites ejecutar títulos de Windows.

Prueba primero una versión oficial de Proton. Utiliza Proton-CachyOS o Proton-GE cuando exista una razón concreta, como una corrección conocida para el juego. Una variante personalizada no es automáticamente mejor para todos los títulos.

## Opciones de lanzamiento

Orden recomendado:

```text
VARIABLES_DE_ENTORNO wrappers %command% argumentos_del_juego
```

Ejemplo con MangoHud:

```text
mangohud %command%
```

No copies opciones de lanzamiento sin comprenderlas. Gamescope, escalado, límites de FPS y variables de Proton pueden tener efectos distintos según compositor y GPU.

## GPU híbrida

### NVIDIA dedicada

Con `nvidia-prime`:

```bash
prime-run aplicacion
```

En Steam:

```text
prime-run %command%
```

### Dos GPUs gestionadas por Mesa

```bash
DRI_PRIME=1 aplicacion
```

En Steam:

```text
DRI_PRIME=1 %command%
```

Verifica la GPU elegida con herramientas del juego, MangoHud o `glxinfo -B` ejecutado con el mismo prefijo.

No uses métodos antiguos como Bumblebee o `nvidia-xrun` en una configuración moderna compatible con PRIME Offload.

## Launchers adicionales

Herramientas como Lutris, Heroic o Faugus Launcher son opcionales. Comprueba primero si están en los repositorios configurados:

```bash
pacman -Si lutris
```

```bash
pacman -Si heroic-games-launcher
```

No asumas que todos proceden de AUR. La disponibilidad cambia entre Arch Linux y CachyOS.

## GameMode y MangoHud

Comprueba disponibilidad:

```bash
pacman -Si gamemode mangohud
```

Ejemplo:

```text
gamemoderun mangohud %command%
```

Valida primero cada wrapper por separado. Más capas no implican automáticamente mejor rendimiento.

## Gamescope

Gamescope puede proporcionar escalado y una sesión de juego controlada, pero su utilidad depende del hardware, el compositor y el título.

Ejemplo genérico:

```text
gamescope -- %command%
```

Añade resolución, escalado o límite de FPS únicamente después de revisar `gamescope --help` y probar el juego.

## Anti-cheat y compatibilidad

La compatibilidad cambia continuamente. Consulta fuentes actuales del juego, ProtonDB y la documentación del anti-cheat. No mantengas una tabla estática como garantía.

Un juego puede ejecutar su modo individual y bloquear el multijugador. Las políticas del editor son tan importantes como la compatibilidad técnica.

## Diagnóstico

### El juego usa la GPU incorrecta

```bash
glxinfo -B
```

```bash
prime-run glxinfo -B
```

O, para Mesa:

```bash
DRI_PRIME=1 glxinfo -B
```

### Vulkan no detecta la GPU

```bash
vulkaninfo --summary
```

Revisa drivers de 64 y 32 bits para la familia correcta.

### Pantalla negra

Prueba sin MangoHud, GameMode, Gamescope ni variables adicionales. Después añade cada componente de uno en uno.

Evita `pkill -f` con patrones amplios. Puede terminar procesos no relacionados.

### Registros de Steam

Inicia Steam desde una terminal para capturar mensajes:

```bash
steam
```

Para Proton puede habilitarse un registro por juego:

```text
PROTON_LOG=1 %command%
```

El archivo aparece normalmente en el directorio personal.

## Casos probados

Las pruebas de rendimiento de un equipo concreto deben mantenerse en una subsección fechada e incluir:

- Modelo de CPU y GPU.
- Driver y kernel.
- Resolución.
- Versión del juego y de Proton.
- Opciones de lanzamiento.
- Resultado observado.

No conviertas temperaturas, consumo, FPS o compatibilidad observados en límites universales.

## Lista de comprobación

- GPU y driver detectados correctamente.
- Vulkan funciona.
- Bibliotecas de 32 bits corresponden a la GPU.
- Steam inicia sin errores.
- El juego usa la GPU deseada.
- Las opciones se prueban una por una.
- Existe un snapshot antes de cambios grandes.
- La compatibilidad se consulta en fuentes actuales.

## Referencias

- Gaming en CachyOS: <https://wiki.cachyos.org/configuration/gaming/>
- GPU híbrida en CachyOS: <https://wiki.cachyos.org/configuration/dual_gpu/>
- ProtonDB: <https://www.protondb.com/>
- MangoHud: <https://github.com/flightlessmango/MangoHud>
- Gamescope: <https://github.com/ValveSoftware/gamescope>
