# Capítulo 15: Gestión de paquetes

[← Cap. 14: Uso de Hyprland](Capítulo-14-Uso-Hyprland.md) · [Índice](./_index.md) · [Cap. 16: Acceso remoto →](Capítulo-16-Acceso-Remoto.md)

## Introducción

CachyOS utiliza Pacman para administrar paquetes precompilados de Arch Linux y CachyOS. Paru añade automatización para AUR, cuyos paquetes se distribuyen como recetas `PKGBUILD` y se compilan localmente.

Para repositorios oficiales y CachyOS, usa Pacman como opción principal. Reserva Paru para AUR o para un flujo combinado que comprendas.

## Pacman

### Actualización completa

```bash
sudo pacman -Syu
```

Arch Linux no admite actualizaciones parciales. Evita refrescar bases sin actualizar, por ejemplo:

```text
pacman -Sy paquete
```

Instalar paquetes contra bases nuevas y un sistema antiguo puede producir incompatibilidades de bibliotecas.

### Instalar

```bash
sudo pacman -S paquete
```

```bash
sudo pacman -S --needed paquete
```

### Buscar

```bash
pacman -Ss termino
```

```bash
pacman -Qs termino
```

### Consultar

```bash
pacman -Si paquete
```

```bash
pacman -Qi paquete
```

```bash
pacman -Ql paquete
```

```bash
pacman -Qo /ruta/al/archivo
```

### Eliminar

```bash
sudo pacman -R paquete
```

```bash
sudo pacman -Rs paquete
```

```bash
sudo pacman -Rns paquete
```

Lee siempre la lista de paquetes que serán eliminados antes de aceptar.

## Paru y AUR

Paru es un wrapper de Pacman y un helper de AUR. Los helpers de AUR no forman parte del soporte oficial de Arch Linux. Debes conocer el proceso manual con `makepkg` y revisar las fuentes antes de instalar.

No ejecutes:

```text
sudo paru
```

Paru solicita elevación cuando Pacman la necesita, pero la compilación de paquetes AUR debe realizarse como usuario normal.

### Buscar e instalar desde AUR

```bash
paru -Ss termino
```

```bash
paru -S paquete-aur
```

### Revisar un PKGBUILD

```bash
paru -Gp paquete-aur
```

O descarga los archivos para inspeccionarlos:

```bash
paru -G paquete-aur
```

Revisa al menos:

- `PKGBUILD`.
- Archivos `.install`.
- Parches incluidos.
- URLs de origen.
- Comandos ejecutados en `prepare()`, `build()` y `package()`.

Si una compilación falla, prueba el proceso con `makepkg` antes de atribuir el error a Paru.

### Actualizar AUR

```bash
paru -Sua
```

Para un flujo combinado de repositorios y AUR puede utilizarse:

```bash
paru -Syu
```

Aun así, revisa las noticias y avisos de CachyOS y Arch antes de actualizaciones importantes.

## Repositorios activos

```bash
pacman-conf --repo-list
```

No codifiques una lista fija de nombres en procedimientos de mantenimiento. Las variantes de repositorio de CachyOS pueden cambiar según la arquitectura y la configuración instalada.

## Huérfanos

Lista dependencias que ya no son necesarias:

```bash
pacman -Qtdq
```

Si la salida está vacía, no hay nada que eliminar.

Para eliminar de forma segura la lista producida:

```bash
pacman -Qtdq | sudo pacman -Rns -
```

Revisa la transacción antes de confirmar. No uses sustitución `$(pacman -Qtdq)` sin manejar el caso vacío.

## Caché de paquetes

La caché permite reinstalar o degradar paquetes sin volver a descargarlos. No conviene eliminarla por completo como mantenimiento rutinario.

`paccache` pertenece al paquete `pacman-contrib`:

```bash
sudo pacman -S --needed pacman-contrib
```

Conserva las tres versiones más recientes:

```bash
sudo paccache -r
```

Conserva una versión de paquetes desinstalados:

```bash
sudo paccache -ruk1
```

Evita usar habitualmente:

```text
pacman -Scc
```

Eliminar toda la caché reduce las opciones de recuperación rápida.

## Mirrors

El proyecto utiliza `cachyos-rate-mirrors`. Para una ejecución manual:

```bash
sudo cachyos-rate-mirrors
```

Comprueba primero su ayuda y configuración instalada:

```bash
cachyos-rate-mirrors --help
```

No reemplaces manualmente la mirrorlist con un comando genérico si el wrapper de CachyOS ya administra varias mirrorlists.

## Verificación de paquetes

Comprueba los archivos de un paquete:

```bash
pacman -Qk paquete
```

Comprueba todos los paquetes, sabiendo que puede producir bastante salida:

```bash
pacman -Qk
```

Los archivos de configuración modificados o ciertos archivos generados pueden requerir interpretación. No elimines ni reinstales paquetes basándote únicamente en una línea sin contexto.

## Snapper y transacciones

`snap-pac` puede crear snapshots `pre/post` alrededor de operaciones de Pacman.

```bash
sudo snapper -c root list
```

`snapper undochange` revierte diferencias de archivos entre snapshots. No equivale al rollback completo del subvolumen raíz realizado por:

```bash
sudo btrfs-rollback ID
```

Para una recuperación completa, consulta el [Capítulo 11](Capítulo-11-Rollback.md).

## Prácticas recomendadas

- Actualiza con `pacman -Syu`.
- Lee avisos de CachyOS y Arch antes de cambios importantes.
- Revisa los `PKGBUILD` del AUR.
- No uses `sudo` para compilar paquetes AUR.
- Conserva varias versiones en la caché.
- Revisa huérfanos antes de eliminarlos.
- Comprueba snapshots antes y después de mantenimiento relevante.
- Evita actualizaciones parciales.

## Referencia rápida

```text
sudo pacman -Syu       Actualizar repositorios oficiales y CachyOS
sudo pacman -S paquete Instalar paquete precompilado
pacman -Ss termino     Buscar en repositorios
pacman -Qi paquete     Consultar paquete instalado
sudo pacman -Rns pkg   Eliminar paquete y dependencias no usadas
paru -S paquete-aur    Compilar e instalar desde AUR
paru -Sua              Actualizar paquetes AUR
sudo paccache -r       Conservar tres versiones en caché
pacman -Qtdq           Listar huérfanos
```

## Referencias

- ArchWiki, Pacman: <https://wiki.archlinux.org/title/Pacman>
- ArchWiki, helpers de AUR: <https://wiki.archlinux.org/title/AUR_helpers>
- Paru: <https://github.com/Morganamilo/paru>
- CachyOS FAQ: <https://wiki.cachyos.org/cachyos_basic/faq/>
