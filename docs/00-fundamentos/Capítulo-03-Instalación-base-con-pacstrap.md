# Capítulo 03: Instalación base con pacstrap

[← Cap. 02: Particionado y montaje](Capítulo-02-Particionado-y-montaje-desde-el-Live-USB.md) · [Índice](../_index.md) · [Cap. 04: Repositorios CachyOS →](Capítulo-04-Repositorios-CachyOS.md)

## Objetivo

`base/install-base.sh` instala el sistema base en `/mnt`, genera `fstab` y prepara los repositorios de CachyOS para el sistema instalado.

## Verificación previa

```bash
findmnt -R /mnt
test -x /usr/bin/pacstrap
```

`@snapshots` ya fue creado y montado en el capítulo anterior. No debe crearse de nuevo durante `pacstrap`.

## Mirrors

Antes de instalar, el script intenta ejecutar `cachyos-rate-mirrors`. Si la herramienta no está disponible, intenta instalarla en el Live USB. Si falla, continúa con la lista existente y muestra una advertencia.

## Paquetes base

La lista actual incluye:

```text
base base-devel
linux-cachyos linux-cachyos-headers linux-firmware
btrfs-progs grub grub-btrfs efibootmgr
networkmanager openssh sudo vim
snapper snap-pac inotify-tools
cachyos-keyring cachyos-mirrorlist
man-db less unzip rsync paru
```

Si se habilita LUKS, añade `cryptsetup`.

El instalador usa los repositorios y la caché del Live USB mediante:

```bash
pacstrap -c /mnt
```

## Reintentos de descarga

El proceso permite hasta tres intentos. Ante errores HTTP o archivos no recuperados:

1. Vuelve a ejecutar la selección de mirrors.
2. Refresca las bases de datos.
3. Reintenta sin descargar otra vez los paquetes ya presentes en caché.

El registro temporal queda en:

```text
/tmp/pacstrap.log
```

## Microcódigo

La lista base actual no instala explícitamente `intel-ucode` ni `amd-ucode`. La detección e instalación de microcódigo debe tratarse en un cambio funcional separado antes de documentarla como automática.

## Generación de fstab

El instalador genera el archivo de forma idempotente:

```bash
genfstab -U /mnt > /mnt/etc/fstab
```

Se usa `>` y no `>>` para evitar entradas duplicadas si el paso se repite.

Verifica:

```bash
cat /mnt/etc/fstab
findmnt --verify --tab-file /mnt/etc/fstab
```

Los puntos principales deben incluir:

```text
/
/home
/var/log
/.snapshots
/var/cache/pacman/pkg
/swap
/boot/efi
/var/lib/docker, si se habilitó
```

## Repositorios del sistema instalado

El Live USB de CachyOS ya dispone de una configuración válida de Pacman. El instalador copia:

```text
/etc/pacman.conf
```

hacia:

```text
/mnt/etc/pacman.conf
```

También copia todas las mirrorlists disponibles cuyo nombre coincida con:

```text
cachyos*-mirrorlist
```

Esto incluye automáticamente variantes presentes en el Live USB, como v3, v4 o znver4, sin mantener una lista fija en el script.

## Entrada al chroot

La configuración posterior se ejecuta con `arch-chroot`. Para comprobar paquetes instalados:

```bash
arch-chroot /mnt pacman -Q \
  linux-cachyos linux-cachyos-headers \
  snapper snap-pac grub grub-btrfs btrfs-progs
```

No uses `uname -r` para verificar el kernel instalado dentro de chroot. Ese comando muestra el kernel del Live USB actualmente en ejecución.

Comprueba archivos de arranque:

```bash
ls -l /mnt/boot
```

## Verificaciones finales

```bash
test -x /mnt/bin/bash
arch-chroot /mnt pacman -Syy
arch-chroot /mnt pacman -Q cachyos-keyring cachyos-mirrorlist
```

Evita `pacman -Sy` como práctica cotidiana en el sistema instalado. Las actualizaciones normales deben ser completas:

```bash
sudo pacman -Syu
```

## Estado esperado

- Sistema base presente en `/mnt`.
- Kernel y headers de CachyOS instalados.
- Herramientas Btrfs, Snapper y GRUB instaladas.
- `fstab` generado sin duplicados.
- Configuración de repositorios copiada desde el Live USB.
- Sistema listo para la configuración en chroot.
