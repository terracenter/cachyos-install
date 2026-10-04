# Capítulo 09: Verificación de snapshots

[← Cap. 08: mkinitcpio](Capítulo-08-mkinitcpio.md) · [Índice](../_index.md) · [Cap. 10: Primer arranque →](Capítulo-10-Primer-arranque.md)

## Objetivo

Este capítulo comprueba que Snapper, el montaje `/.snapshots` y la estructura Btrfs creada por el instalador son coherentes.

Durante la instalación desde el Live USB, algunos comandos se ejecutan dentro de `arch-chroot` y requieren `--no-dbus`. Después del primer arranque normal, utiliza Snapper sin esa opción.

## Verificación durante la instalación

Confirma el montaje:

```bash
findmnt /mnt/.snapshots
```

Comprueba la configuración generada:

```bash
test -f /mnt/etc/snapper/configs/root
```

```bash
grep '^SNAPPER_CONFIGS=' /mnt/etc/conf.d/snapper
```

El valor esperado es:

```text
SNAPPER_CONFIGS="root"
```

## Snapshot inicial

El instalador crea un snapshot con descripción:

```text
sistema-base-instalado
```

Y lo marca como importante:

```text
important=yes
```

Desde el chroot puede listarse con:

```bash
arch-chroot /mnt snapper --no-dbus -c root list
```

El número concreto no debe asumirse. El snapshot puede no ser `1` si la configuración ya creó otras entradas.

## Verificación después del primer arranque

En el sistema instalado:

```bash
sudo snapper -c root list-configs
```

```bash
sudo snapper -c root list
```

```bash
findmnt /
```

```bash
findmnt /.snapshots
```

La configuración `root` debe existir y el snapshot inicial debe aparecer por su descripción.

## Relación entre Snapper y Btrfs

Los números mostrados por Snapper no son los IDs internos de subvolumen Btrfs.

Para inspeccionar la estructura montada sin asumir un dispositivo como `/dev/nvme0n1p2`, utiliza el punto de montaje actual:

```bash
sudo btrfs subvolume list /
```

Busca rutas similares a:

```text
@snapshots/N/snapshot
```

`N` corresponde al número administrado por Snapper. Los IDs mostrados al principio de cada línea corresponden a Btrfs y pueden variar.

## Verificar timers

```bash
systemctl is-enabled snapper-timeline.timer
```

```bash
systemctl is-enabled snapper-cleanup.timer
```

```bash
systemctl list-timers 'snapper-*'
```

Los timers deben estar habilitados. `snapper-timeline.timer` crea snapshots temporales y `snapper-cleanup.timer` aplica las políticas configuradas.

## Integración con Pacman

`snap-pac` crea snapshots alrededor de transacciones de paquetes. No instales software innecesario únicamente para probarlo en un equipo de producción.

Después de una operación real de mantenimiento, comprueba:

```bash
sudo snapper -c root list
```

Deberían aparecer entradas `pre` y `post` relacionadas con la transacción.

## Verificar `grub-btrfs`

Primero confirma que Snapper contiene snapshots. Luego revisa la unidad disponible:

```bash
systemctl is-enabled grub-btrfsd.service 2>/dev/null
```

```bash
systemctl is-enabled grub-btrfs.path 2>/dev/null
```

El instalador intenta habilitar una de las dos. No asumas que ambas existen.

## Errores frecuentes

### La configuración `root` no existe

```bash
sudo snapper list-configs
```

```bash
sudo test -f /etc/snapper/configs/root
```

No ejecutes `snapper create-config` sin revisar primero `/.snapshots`, porque el instalador ya prepara ese subvolumen y la configuración directamente.

### `/.snapshots` no está montado

```bash
findmnt /.snapshots
```

Revisa `/etc/fstab` y la existencia del subvolumen `@snapshots`.

### El snapshot inicial no tiene el número esperado

Es normal. Identifícalo por la descripción y el metadato, no por un número fijo.

### Snapper funciona, pero GRUB no muestra snapshots

Snapper y GRUB son componentes distintos. Revisa el servicio de `grub-btrfs` y regenera `grub.cfg` solo después de confirmar que los snapshots existen.

## Estado esperado

- La configuración `root` aparece en Snapper.
- `/.snapshots` está montado desde `@snapshots`.
- El snapshot `sistema-base-instalado` existe y está marcado como importante.
- Los timers de creación y limpieza están habilitados.
- La estructura Btrfs contiene las rutas administradas por Snapper.
- Una unidad de actualización de `grub-btrfs` está disponible cuando el paquete la proporciona.

## Referencias

- Snapper: <https://snapper.io/manpages/snapper.html>
- CachyOS, snapshots Btrfs: <https://wiki.cachyos.org/configuration/btrfs_snapshots/>
- Btrfs, subvolúmenes: <https://btrfs.readthedocs.io/en/latest/Subvolumes.html>
