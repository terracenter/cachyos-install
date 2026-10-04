# Capítulo 08: mkinitcpio

[← Cap. 07: GRUB](Capítulo-07-Configuración-de-GRUB.md) · [Índice](../_index.md) · [Cap. 09: Verificación de snapshots →](Capítulo-09-Verificacion-de-Snapshots.md)

## Objetivo

`mkinitcpio` genera las imágenes initramfs necesarias para arrancar el kernel. El instalador crea la lista de hooks según las opciones seleccionadas y regenera todos los presets instalados.

`mkinitcpio` admite enfoques basados en BusyBox o en systemd según los hooks configurados. El orden y conjunto de hooks debe corresponder al método elegido por el instalador.

## Configuración generada

El instalador establece:

```text
MODULES=(btrfs)
```

Y construye `HOOKS` a partir de:

```text
base udev autodetect microcode modconf kms keyboard keymap consolefont block
```

Después añade de forma condicional:

- `encrypt`, si se habilitó LUKS.
- `resume`, si se habilitó hibernación.

Y completa la lista con:

```text
filesystems btrfs fsck
```

La línea exacta depende de las opciones elegidas. No utilices un `sed` que inserte `btrfs` cada vez que se ejecuta, porque puede duplicar hooks.

## Revisar la configuración

Dentro del sistema instalado:

```bash
grep -E '^(MODULES|HOOKS)=' /etc/mkinitcpio.conf
```

También revisa si se habilitaron LUKS o hibernación:

```bash
grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub
```

## Generar initramfs

El instalador ejecuta:

```bash
mkinitcpio -P
```

`-P` procesa todos los presets encontrados en `/etc/mkinitcpio.d/`. Puede tardar y debe terminar sin errores. Los paquetes de kernel regeneran normalmente sus imágenes mediante hooks de Pacman.

## Verificar presets e imágenes

Lista los presets:

```bash
find /etc/mkinitcpio.d -maxdepth 1 -type f -name '*.preset' -print
```

Lista las imágenes:

```bash
find /boot -maxdepth 1 -type f -name 'initramfs-*.img' -ls
```

Para inspeccionar una imagen concreta:

```bash
lsinitcpio /boot/initramfs-linux-cachyos.img | less
```

No asumas que todos los equipos generan exactamente el mismo nombre o una imagen fallback. Depende de los presets instalados.

## Btrfs

El proyecto incluye el módulo `btrfs` y el hook `btrfs` de la instalación actual. Esto expresa una decisión del proyecto, pero no debe afirmarse que un hook externo antiguo como `mkinitcpio-btrfs` sea obligatorio para todo sistema con raíz Btrfs.

El paquete histórico `mkinitcpio-btrfs` ofrece funciones avanzadas y lleva años sin una actualización estable; no forma parte de este instalador.

## LUKS

Cuando se habilita cifrado, la configuración incluye el hook `encrypt` y GRUB recibe un parámetro `cryptdevice`. Verifica que ambos lados sean coherentes antes de reiniciar.

## Hibernación

Cuando se habilita hibernación, el instalador añade `resume` y calcula el `resume_offset` del swapfile Btrfs. Comprueba los parámetros de GRUB y regenera tanto initramfs como `grub.cfg` si se modifican posteriormente.

## Validación

```bash
sudo mkinitcpio -P
```

Después:

```bash
find /boot -maxdepth 1 -type f -name 'initramfs-*.img' -size +0 -print
```

Comprueba que no existan errores recientes:

```bash
sudo journalctl -b -p err
```

## Problemas frecuentes

### Hook duplicado

Revisa:

```bash
grep '^HOOKS=' /etc/mkinitcpio.conf
```

Edita la lista completa una sola vez. No ejecutes sustituciones repetitivas que vuelvan a insertar el mismo hook.

### Imagen ausente

Comprueba el paquete de kernel y su preset:

```bash
pacman -Q linux-cachyos
ls -l /etc/mkinitcpio.d/
```

### El sistema usa otro kernel

`mkinitcpio -P` procesa todos los presets, no únicamente `linux-cachyos`. Revisa los nombres reales en `/etc/mkinitcpio.d/` y `/boot`.

## Estado esperado

- `/etc/mkinitcpio.conf` contiene módulos y hooks coherentes con Btrfs, LUKS e hibernación.
- Todos los presets terminan sin errores.
- Las imágenes initramfs existen y tienen tamaño mayor que cero.
- GRUB apunta a parámetros compatibles con la configuración del initramfs.

## Referencias

- ArchWiki, mkinitcpio: <https://wiki.archlinux.org/title/Mkinitcpio>
- ArchWiki, Btrfs: <https://wiki.archlinux.org/title/Btrfs>
