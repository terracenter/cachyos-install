# Capítulo 07: Configuración de GRUB

[← Cap. 06: Snapper](Capítulo-06-Configuración-de-Snapper.md) · [Índice](../_index.md) · [Cap. 08: mkinitcpio →](Capítulo-08-mkinitcpio.md)

## Objetivo

El instalador configura GRUB para UEFI, genera una copia de respaldo en la ruta removible y habilita la integración con snapshots mediante `grub-btrfs`.

Este capítulo describe únicamente las funciones presentes en `base/install-base.sh`. La colección histórica de temas GRUB y la sincronización con temas del escritorio no forman parte del flujo actual.

## Punto de montaje EFI

La partición EFI se monta en:

```text
/boot/efi
```

Durante la instalación puede comprobarse desde el Live USB:

```bash
findmnt /mnt/boot/efi
```

Dentro del chroot:

```bash
findmnt /boot/efi
```

No uses `/efi` ni un dispositivo fijo como `/dev/nvme0n1p1` en la documentación del proyecto.

## Parámetros del kernel

El instalador construye `GRUB_CMDLINE_LINUX_DEFAULT` a partir de las opciones elegidas:

```text
quiet net.ifnames=0 biosdevname=0
```

Puede añadir:

- Parámetros específicos detectados para GPU.
- `cryptdevice=...` y `root=...` cuando se usa LUKS.
- `resume=...` y `resume_offset=...` cuando se habilita hibernación.

Revisa el resultado:

```bash
grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub
```

## Menú y salida gráfica

El instalador configura:

```text
GRUB_TIMEOUT_STYLE="menu"
GRUB_TERMINAL_OUTPUT="gfxterm"
GRUB_GFXMODE="auto"
GRUB_GFXPAYLOAD_LINUX="keep"
GRUB_FONT="/boot/grub/fonts/unicode.pf2"
```

La fuente se copia a:

```text
/boot/grub/fonts/unicode.pf2
```

Estas opciones mantienen visible el menú y habilitan una salida gráfica básica. El instalador no configura actualmente una colección de temas visuales de GRUB.

## Instalación UEFI

Dentro del chroot se ejecutan dos instalaciones:

```bash
grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=CachyOS \
  --recheck
```

Y una copia de respaldo para la ruta UEFI removible:

```bash
grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --removable
```

Después genera:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

## Integración con snapshots

`grub-btrfs` añade un submenú con snapshots Btrfs. El proyecto configura su nombre como:

```text
CachyOS Linux Snapshots
```

El archivo de configuración es:

```text
/etc/default/grub-btrfs/config
```

Comprueba:

```bash
grep '^GRUB_BTRFS_SUBMENUNAME=' \
  /etc/default/grub-btrfs/config
```

`grub-btrfs` puede detectar snapshots de Snapper y generar entradas para arrancarlos. El servicio proporcionado puede regenerar `grub.cfg` cuando cambia el directorio de snapshots.

## Servicio de actualización

El instalador intenta habilitar, en este orden:

```text
grub-btrfsd.service
grub-btrfs.path
```

Comprueba qué unidad existe y está activa:

```bash
systemctl is-enabled grub-btrfsd.service 2>/dev/null
systemctl is-enabled grub-btrfs.path 2>/dev/null
```

Después del arranque:

```bash
systemctl status grub-btrfsd.service 2>/dev/null
systemctl status grub-btrfs.path 2>/dev/null
```

No se garantiza que los snapshots aparezcan exactamente a partir del segundo arranque. Su disponibilidad depende de que existan snapshots, de que el servicio funcione y de que `grub.cfg` se haya generado correctamente.

## Arrancar un snapshot no es un rollback permanente

Seleccionar un snapshot desde GRUB permite probar un estado anterior. No reemplaza automáticamente el subvolumen raíz activo.

Para un rollback permanente, utiliza el procedimiento del [Capítulo 11](Capítulo-11-Rollback.md).

CachyOS también advierte que los snapshots no sustituyen respaldos externos y que los problemas del bootloader requieren procedimientos separados.

## Validación

Comprueba la instalación EFI:

```bash
find /boot/efi/EFI -maxdepth 2 -type f -print
```

Comprueba GRUB:

```bash
test -s /boot/grub/grub.cfg
grep -E '^GRUB_(TIMEOUT_STYLE|TERMINAL_OUTPUT|GFXMODE|GFXPAYLOAD_LINUX|FONT)=' \
  /etc/default/grub
```

Comprueba los snapshots antes de diagnosticar GRUB:

```bash
sudo snapper -c root list
```

## Problemas frecuentes

### No aparece el submenú de snapshots

1. Confirma que existan snapshots.
2. Comprueba la unidad `grub-btrfsd.service` o `grub-btrfs.path`.
3. Revisa `/etc/default/grub-btrfs/config`.
4. Regenera manualmente, si es necesario:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### El rollback restaura `/`, pero `/boot` no coincide

La partición EFI y ciertos archivos de `/boot` pueden quedar fuera del snapshot raíz. Después de un rollback revisa kernel, initramfs y configuración de GRUB antes de considerar completada la recuperación.

### El tema del escritorio cambió, pero GRUB no

Es el comportamiento actual. `theme-apply` no sincroniza temas de GRUB.

## Estado esperado

- EFI montada en `/boot/efi`.
- GRUB instalado con identificador `CachyOS`.
- Copia UEFI removible instalada.
- Menú visible con salida `gfxterm`.
- `grub.cfg` generado.
- Submenú de snapshots configurado.
- Unidad de actualización de `grub-btrfs` habilitada cuando está disponible.

## Referencias

- grub-btrfs: <https://github.com/Antynea/grub-btrfs>
- Manual de grub-btrfs: <https://man.archlinux.org/man/extra/grub-btrfs/grub-btrfs.8.en>
- CachyOS, snapshots Btrfs: <https://wiki.cachyos.org/configuration/btrfs_snapshots/>
