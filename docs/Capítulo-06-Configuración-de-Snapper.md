# Capítulo 06: Configuración y mantenimiento de Snapper

[← Cap. 05: Configuración del sistema](Capítulo-05-Configuración-del-sistema.md) · [Índice](./_index.md) · [Cap. 07: GRUB →](Capítulo-07-Configuración-de-GRUB.md)

## Objetivo

El instalador configura Snapper para administrar snapshots del subvolumen raíz Btrfs. Este capítulo describe la configuración realmente generada por `base/install-base.sh` y su mantenimiento.

## Estructura requerida

El instalador crea y monta:

```text
@snapshots → /.snapshots
```

La configuración se guarda en:

```text
/etc/snapper/configs/root
```

Y se registra en:

```text
/etc/conf.d/snapper
```

## Política instalada

La configuración actual usa:

```text
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="50"
NUMBER_LIMIT_IMPORTANT="10"

TIMELINE_CREATE="yes"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"

EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
```

Interpretación:

- Se conservan hasta 50 snapshots administrados por el algoritmo `number`.
- Hasta 10 snapshots importantes pueden conservarse dentro de esa política.
- La línea temporal conserva 5 horarios y 7 diarios.
- No conserva automáticamente históricos semanales, mensuales ni anuales.
- Los pares `pre/post` sin cambios pueden eliminarse.
- La edad mínima de limpieza es de 1800 segundos.

## Servicios de mantenimiento

El instalador habilita:

```bash
sudo systemctl enable --now snapper-timeline.timer
sudo systemctl enable --now snapper-cleanup.timer
```

Comprueba su estado:

```bash
systemctl status snapper-timeline.timer
systemctl status snapper-cleanup.timer
systemctl list-timers 'snapper-*'
```

## Snapshot inicial protegido

El instalador crea:

```bash
sudo snapper -c root create   --description "sistema-base-instalado"   --userdata "important=yes"
```

Durante la instalación desde chroot se utiliza `--no-dbus`. Después del arranque normal no es necesario usar esa opción.

Comprueba el snapshot:

```bash
sudo snapper -c root list
```

## Snapshots de paquetes

Con `snap-pac`, las operaciones de Pacman pueden crear pares `pre/post` automáticamente.

Comprueba la integración después de una operación real de paquetes:

```bash
sudo snapper -c root list
```

No instales paquetes innecesarios únicamente para generar snapshots en un equipo de producción.

## Limpieza manual

Consulta primero la lista:

```bash
sudo snapper -c root list
```

Para ejecutar los algoritmos configurados:

```bash
sudo snapper -c root cleanup number
sudo snapper -c root cleanup timeline
sudo snapper -c root cleanup empty-pre-post
```

Para eliminar un snapshot concreto:

```bash
sudo snapper -c root delete ID
```

Sustituye `ID` por un número revisado previamente. No elimines el snapshot base ni otros snapshots importantes sin comprender sus consecuencias.

## Espacio usado

Revisa periódicamente:

```bash
sudo btrfs filesystem usage /
sudo btrfs filesystem df /
sudo snapper -c root list
```

La configuración contiene valores `SPACE_LIMIT` y `FREE_LIMIT`, pero la limpieza basada en espacio depende de cuotas Btrfs correctamente configuradas. El proyecto no debe prometer esa protección hasta que las cuotas se habiliten y validen en un commit independiente.

## Backups `@_old_FECHA`

Los subvolúmenes creados por `btrfs-rollback` con nombres como:

```text
@_old_20260929_091500
```

no forman parte de Snapper. Por tanto:

- No aparecen como snapshots normales.
- No son eliminados por `snapper-cleanup.timer`.
- Deben revisarse con `btrfs subvolume list`.
- Se eliminan manualmente por nombre exacto después de validar el rollback.

Ejemplo de localización, sin eliminar:

```bash
sudo btrfs subvolume list / | grep '@_old_'
```

No uses comodines con `btrfs subvolume delete`.

## Validación

```bash
sudo snapper -c root list-configs
sudo snapper -c root get-config
findmnt /
findmnt /.snapshots
systemctl --failed
```

También comprueba permisos:

```bash
sudo ls -ld /.snapshots
```

## Problemas frecuentes

### La configuración `root` no existe

```bash
sudo snapper list-configs
sudo test -f /etc/snapper/configs/root
```

No ejecutes `create-config` sobre una estructura ya preparada por el instalador sin revisar primero `/.snapshots` y `/etc/snapper/configs/root`.

### Los snapshots no aparecen en GRUB

Snapper y GRUB son componentes distintos. Primero confirma que los snapshots existan. Después revisa `grub-btrfs` y su servicio.

### El espacio no disminuye inmediatamente

Btrfs comparte bloques entre snapshots. La eliminación de un snapshot no implica que todos sus bloques sean liberados si siguen referenciados por otros subvolúmenes.

## Referencias

- Snapper manual: <https://snapper.io/manpages/snapper.html>
- Snapper configuration: <https://snapper.io/manpages/snapper-configs.html>
- CachyOS Wiki, Btrfs snapshots: <https://wiki.cachyos.org/configuration/btrfs_snapshots/>
