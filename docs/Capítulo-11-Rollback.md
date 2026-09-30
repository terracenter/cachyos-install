# Capítulo 11: Rollback seguro con Btrfs y Snapper

[← Cap. 10: Primer arranque](Capítulo-10-Primer-arranque.md) · [Índice](./_index.md) · [Cap. 12: Instalación de Hyprland →](Capítulo-12-Instalacion-Hyprland.md)

## Objetivo

Este capítulo explica cómo evaluar un snapshot y cómo realizar un rollback permanente con el helper instalado por el proyecto.

> **Advertencia:** un rollback modifica el subvolumen raíz y normalmente requiere reiniciar para usar el sistema restaurado. En un equipo de producción, planifica la interrupción y conserva respaldos externos.

## Antes de restaurar

1. Identifica el problema.
2. Confirma que el snapshot elegido es anterior al fallo.
3. Revisa qué datos están dentro de `@` y cuáles pertenecen a subvolúmenes separados.
4. Guarda el trabajo abierto.
5. Confirma que dispones de acceso de recuperación, Live USB y respaldo de datos importantes.

Lista los snapshots:

```bash
sudo snapper -c root list
```

Revisa cambios entre snapshots cuando sea útil:

```bash
sudo snapper -c root status ID1..ID2
```

## Qué restaura el helper

`btrfs-rollback N` utiliza el contenido de:

```text
@snapshots/N/snapshot
```

para crear un nuevo subvolumen raíz `@`.

No restaura automáticamente:

- `@home`
- `@log`
- `@pkg`
- `@swap`
- `@docker`
- La partición EFI
- Otros discos o sistemas de archivos

## Diferencia entre IDs

El argumento `N` es el número mostrado por Snapper. Durante el rollback se crea un nuevo subvolumen Btrfs, que recibe su propio ID interno.

El helper no crea un nuevo snapshot de Snapper. Por eso, restaurar el snapshot `3` no genera automáticamente el snapshot `4`.

## Rollback con el helper

Sintaxis:

```bash
sudo btrfs-rollback N
```

Ejemplo:

```bash
sudo btrfs-rollback 3
```

El helper:

1. Detecta el dispositivo que contiene `/`.
2. Monta el nivel superior Btrfs en un directorio temporal.
3. Verifica que exista `@snapshots/N/snapshot`.
4. Renombra el `@` actual como `@_old_FECHA_HORA`.
5. Crea un snapshot grabable del estado elegido con el nombre `@`.
6. Establece el nuevo `@` como subvolumen predeterminado.
7. Desmonta el directorio temporal.

Al finalizar informa que:

- Se creó un nuevo subvolumen `@`.
- No se creó un nuevo ID de Snapper.
- El sistema anterior permanece en `@_old_FECHA_HORA`.

## Reinicio

No reinicies automáticamente durante la ejecución. Primero revisa la salida del helper y confirma que no existan errores.

Cuando sea seguro interrumpir el equipo:

```bash
sudo reboot
```

## Validación posterior

Después de arrancar:

```bash
findmnt /
sudo snapper -c root list
systemctl --failed
```

Comprueba también los servicios y aplicaciones relacionados con el problema original.

El hecho de que el escritorio abra no es suficiente. Valida red, almacenamiento, audio, sesión gráfica y carga de trabajo habitual antes de eliminar el sistema anterior.

## Backup `@_old_FECHA`

Localiza los backups desde el nivel superior Btrfs. Primero identifica el dispositivo raíz:

```bash
findmnt -no SOURCE /
```

Como el origen puede incluir una opción `[/@]`, no copies ciegamente esa salida en un comando de montaje. El helper realiza la detección necesaria.

Los `@_old_FECHA` no son snapshots administrados por Snapper y no se limpian automáticamente.

## Eliminación segura del sistema anterior

Solo después de validar el rollback durante un periodo prudente:

1. Monta el nivel superior Btrfs en una ruta temporal.
2. Lista los subvolúmenes.
3. Comprueba el nombre exacto que deseas eliminar.
4. Elimina uno solo por vez.
5. Desmonta la ruta temporal.

Nunca uses:

```bash
sudo btrfs subvolume delete /ruta/@_old_*
```

El comodín puede seleccionar más backups de los previstos.

La eliminación concreta debe parecerse a:

```bash
sudo btrfs subvolume delete /ruta/exacta/@_old_20260929_091500
```

Este es solo un patrón ilustrativo. Verifica antes la ruta de montaje y el nombre real.

## Recuperación desde Live USB

Utiliza un Live USB cuando el sistema no arranque o el helper no pueda ejecutarse.

Procedimiento general:

1. Inicia el Live USB en modo UEFI.
2. Desbloquea LUKS si corresponde.
3. Identifica el sistema Btrfs con `lsblk`, `blkid` y `findmnt`.
4. Monta el nivel superior con `subvolid=5`.
5. Revisa `@`, `@snapshots` y los backups existentes.
6. Conserva el `@` actual con un nombre único.
7. Crea el nuevo `@` desde el snapshot elegido.
8. Establece el nuevo subvolumen predeterminado.
9. Desmonta de forma ordenada.
10. Reinicia únicamente cuando todas las operaciones hayan terminado correctamente.

No se incluye un dispositivo fijo como `/dev/nvme0n1p2`, porque la ruta cambia entre equipos y cuando se usa LUKS.

## GRUB y `/boot`

El helper actual no ejecuta `grub-mkconfig`. Además, si `/boot` o la partición EFI están fuera de `@`, sus archivos no se restauran junto con el snapshot raíz.

Después de un rollback, verifica la coherencia entre:

- Paquetes de kernel restaurados en `/`.
- Imágenes de kernel e initramfs en `/boot`.
- Configuración de GRUB.

Si detectas una diferencia, corrígela desde el sistema restaurado o mediante `arch-chroot` antes de asumir que el rollback está completo.

## Problemas frecuentes

### El snapshot no existe

```bash
sudo snapper -c root list
```

Usa exclusivamente un ID mostrado por la configuración `root`.

### El sistema arranca, pero los datos de usuario no cambiaron

Es el comportamiento esperado cuando `/home` está en `@home`. El rollback de `@` no reemplaza `@home`.

### Aparecen muchos `@_old_*`

Revisa cada uno y elimina manualmente los que ya no sean necesarios. Snapper no los administra.

### El número siguiente no es consecutivo al snapshot restaurado

Es normal. Los IDs representan el historial de creación, no la versión activa del sistema.

## Referencias

- CachyOS Wiki, Btrfs snapshots: <https://wiki.cachyos.org/configuration/btrfs_snapshots/>
- Snapper manual: <https://snapper.io/manpages/snapper.html>
- Btrfs subvolume documentation: <https://btrfs.readthedocs.io/en/latest/Subvolumes.html>
