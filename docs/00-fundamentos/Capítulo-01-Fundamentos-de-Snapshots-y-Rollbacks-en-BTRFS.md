# Capítulo 01: Fundamentos de snapshots y rollback en Btrfs

[Índice](../_index.md) · [Cap. 02: Particionado y montaje →](Capítulo-02-Particionado-y-montaje-desde-el-Live-USB.md)

## Objetivo

Este capítulo explica los conceptos necesarios para entender la estructura Btrfs del proyecto, los snapshots administrados por Snapper y el procedimiento de rollback. No contiene operaciones destructivas.

## Btrfs y subvolúmenes

Btrfs permite dividir un sistema de archivos en subvolúmenes administrables de forma independiente. El instalador usa esta estructura:

```text
@             → /
@home         → /home
@log          → /var/log
@snapshots    → /.snapshots
@pkg          → /var/cache/pacman/pkg
@swap         → /swap
@docker       → /var/lib/docker, cuando se solicita
```

La separación es importante durante un rollback. El helper restaura el subvolumen raíz `@`, pero no reemplaza automáticamente `@home`, `@log`, `@pkg`, `@swap` ni `@docker`.

## Qué es un snapshot

Un snapshot Btrfs captura el estado de un subvolumen en un momento concreto. Inicialmente comparte bloques con el origen y solo consume espacio adicional a medida que los datos divergen.

Un snapshot es útil para recuperarse de:

- Actualizaciones defectuosas.
- Cambios de configuración que rompen el sistema.
- Instalaciones o eliminaciones de paquetes no deseadas.
- Modificaciones accidentales dentro del subvolumen incluido.

## Qué no es un snapshot

Un snapshot **no es un respaldo externo**. Si falla el disco que contiene el sistema de archivos, también pueden perderse sus snapshots.

Mantén copias independientes de los datos importantes, preferiblemente en otro dispositivo o ubicación.

Los snapshots tampoco resuelven por sí solos:

- Fallos físicos del almacenamiento.
- Daños de la partición EFI.
- Problemas del cargador de arranque.
- Archivos ubicados en subvolúmenes que no fueron restaurados.
- Datos externos al sistema de archivos Btrfs.

## Snapper

Snapper administra snapshots y sus metadatos. La configuración del proyecto se llama `root` y opera sobre `/`.

```bash
sudo snapper -c root list
```

Snapper distingue:

- `single`: snapshot independiente.
- `pre`: estado anterior a una operación.
- `post`: estado posterior relacionado con un snapshot `pre`.

`snap-pac` crea pares `pre/post` alrededor de operaciones de paquetes.

## Identificadores

No confundas estos valores:

1. **Número de Snapper:** identifica una entrada en `snapper list`.
2. **ID de subvolumen Btrfs:** identifica internamente un subvolumen.
3. **Nombre del subvolumen:** por ejemplo `@`, `@snapshots` o `@_old_FECHA`.

Al restaurar el snapshot de Snapper número `3`, el helper crea un nuevo subvolumen Btrfs llamado `@`. No crea automáticamente el snapshot de Snapper número `4`.

Cuando Snapper vuelva a crear un snapshot, seguirá su secuencia histórica. Los números identifican la creación del snapshot, no la versión lógica del sistema que contiene.

## Snapshot inicial

Al terminar la instalación, el proyecto crea:

```text
sistema-base-instalado
```

con el metadato:

```text
important=yes
```

Este snapshot representa el primer estado base recuperable. Debe conservarse mientras siga siendo útil, pero no sustituye una copia de seguridad.

## Rollback

El rollback permanente del proyecto sigue este modelo:

```text
snapshot elegido
      ↓
nuevo subvolumen @
      ↓
@ anterior renombrado a @_old_FECHA
      ↓
nuevo @ establecido como subvolumen predeterminado
```

El backup `@_old_FECHA` no es administrado por Snapper y no se elimina automáticamente. Debe revisarse y eliminarse manualmente, por su nombre exacto, solo después de validar el sistema restaurado.

## Mantenimiento

Los snapshots consumen espacio conforme cambian los datos. El proyecto configura limpieza por cantidad, línea de tiempo y pares vacíos. Revisa periódicamente:

```bash
sudo snapper -c root list
sudo btrfs filesystem usage /
sudo btrfs subvolume list /
```

No elimines snapshots o subvolúmenes únicamente porque tengan un número antiguo. Primero confirma su descripción, fecha, importancia y propósito.

## Principios de seguridad

- Nunca uses comodines para eliminar `@_old_*`.
- No elimines el sistema anterior inmediatamente después de un rollback.
- No reinicies un equipo de producción sin haber revisado el procedimiento.
- Verifica siempre el sistema de archivos y el dispositivo antes de montar o modificar subvolúmenes.
- Conserva respaldos externos de los datos importantes.

## Referencias

- CachyOS Wiki, Btrfs snapshots: <https://wiki.cachyos.org/configuration/btrfs_snapshots/>
- Snapper manual: <https://snapper.io/manpages/snapper.html>
- Snapper configuration: <https://snapper.io/manpages/snapper-configs.html>
