# Capítulo 10: Primer arranque

[← Cap. 09: Verificación de snapshots](Capítulo-09-Verificacion-de-Snapshots.md) · [Índice](./_index.md) · [Cap. 11: Rollback →](Capítulo-11-Rollback.md)

## Objetivo

Este capítulo cubre la salida segura del entorno de instalación y las validaciones no destructivas del primer arranque.

## Antes de salir del Live USB

Comprueba que el instalador terminó sin errores y que `/mnt` contiene un sistema completo:

```bash
test -x /mnt/bin/bash
```

```bash
test -s /mnt/boot/grub/grub.cfg
```

```bash
findmnt -R /mnt
```

## Desactivar swap y desmontar

Si el instalador dejó activo el swapfile dentro de `/mnt`:

```bash
swapoff /mnt/swap/swapfile
```

Desmonta de forma recursiva:

```bash
umount -R /mnt
```

Comprueba:

```bash
findmnt -R /mnt
```

No debe mostrar montajes activos. Si se usó LUKS, cierra el mapeo solo después de desmontar todos los sistemas de archivos:

```bash
cryptsetup close cryptroot
```

Ejecuta ese último comando únicamente si existe el mapeo y ya no está en uso.

## Primer reinicio

El primer arranque requiere reiniciar desde el Live USB hacia el sistema instalado:

```bash
reboot
```

Retira el medio de instalación cuando el firmware o el equipo lo permitan.

## Inicio de sesión

Inicia sesión con el usuario creado durante la instalación. La cuenta root tiene la contraseña bloqueada y la administración se realiza mediante `sudo`.

Comprueba:

```bash
id
```

```bash
sudo -v
```

## Kernel en ejecución

```bash
uname -r
```

La salida debe corresponder al kernel de CachyOS en ejecución. Para revisar además el paquete instalado:

```bash
pacman -Q linux-cachyos linux-cachyos-headers
```

## Montajes Btrfs

```bash
findmnt -t btrfs
```

Comprueba individualmente:

```bash
findmnt /
```

```bash
findmnt /home
```

```bash
findmnt /.snapshots
```

```bash
findmnt /var/log
```

```bash
findmnt /var/cache/pacman/pkg
```

`/var/lib/docker` solo existirá como subvolumen separado si se seleccionó durante la instalación.

## Swap e hibernación

```bash
swapon --show
```

Si se habilitó hibernación, confirma los parámetros del kernel:

```bash
cat /proc/cmdline
```

No pruebes hibernación en un equipo de producción hasta verificar el swap, `resume` y `resume_offset`.

## Servicios

```bash
systemctl --failed
```

```bash
systemctl is-active NetworkManager
```

```bash
systemctl is-enabled snapper-timeline.timer
```

```bash
systemctl is-enabled snapper-cleanup.timer
```

Para `grub-btrfs`, revisa la unidad existente:

```bash
systemctl status grub-btrfsd.service 2>/dev/null
```

```bash
systemctl status grub-btrfs.path 2>/dev/null
```

No dependas de una frase exacta del log, porque puede cambiar entre versiones.

## Snapshots

```bash
sudo snapper -c root list
```

Debe aparecer `sistema-base-instalado`. El número concreto puede variar.

No es necesario reiniciar una segunda vez solo para comprobar el submenú de GRUB. Primero valida Snapper, la unidad de `grub-btrfs` y el contenido actual de `grub.cfg`:

```bash
grep -i 'CachyOS Linux Snapshots' /boot/grub/grub.cfg
```

Si el submenú todavía no fue generado, revisa el servicio y, cuando sea apropiado, ejecuta:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

## Red

Comprueba la conexión y la ruta:

```bash
nmcli general status
```

```bash
ip route
```

```bash
getent hosts cachyos.org
```

`ping` puede estar bloqueado por algunas redes; la resolución DNS y el estado de NetworkManager son comprobaciones más útiles.

## Registros

```bash
journalctl -b -p err
```

```bash
dmesg --level=err,warn
```

Revisa los mensajes antes de instalar el escritorio o aplicaciones adicionales.

## Punto de control

Antes de continuar:

- El usuario puede usar `sudo`.
- El kernel de CachyOS está activo.
- Los subvolúmenes Btrfs están montados correctamente.
- El swapfile aparece en `swapon --show`.
- NetworkManager funciona.
- No hay servicios críticos fallidos.
- Snapper muestra el snapshot inicial.
- GRUB e initramfs existen.

No hagas reinicios adicionales salvo que una prueba concreta lo requiera.

## Referencias

- CachyOS Wiki: <https://wiki.cachyos.org/>
- ArchWiki, revisión general del sistema: <https://wiki.archlinux.org/title/System_maintenance>
