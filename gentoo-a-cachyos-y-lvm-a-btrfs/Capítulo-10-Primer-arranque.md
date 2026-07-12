← [Cap. 09 — Verificación de Snapshots](Capítulo-09-Verificacion-de-Snapshots.md) · [Índice](..) · [Cap. 11 — Rollback](Capítulo-11-Rollback.md) →

---

En este capítulo salimos del entorno chroot, desmontamos todas las particiones y reiniciamos en el sistema instalado.

---

## 1. Salir del chroot

```bash
exit
```

El prompt volverá al entorno Live USB.

---

## 2. Desmontar todas las particiones

```bash
umount -R /mnt
```

Verifica que no queda nada montado en `/mnt`:

```bash
findmnt -R /mnt
```

No debe mostrar ninguna salida.

---

## 3. Reiniciar

```bash
reboot
```

Retira el USB cuando la pantalla quede en negro o cuando el firmware lo indique. El sistema arrancará desde el disco instalado.

---

## 4. Verificación post-arranque

Una vez dentro del sistema instalado, inicia sesión con tu usuario (`usuario`) y verifica el estado general:

Confirma que el sistema arrancó con el kernel de CachyOS:

```bash
uname -r
```

Resultado esperado:

```text
6.x.x-cachyos
```

Confirma que los subvolúmenes BTRFS están montados correctamente:

```bash
findmnt -t btrfs
```

Resultado esperado:

```text
TARGET                      SOURCE                        FSTYPE  OPTIONS
/                           /dev/nvme0n1p2[/@]            btrfs   rw,noatime,...
├─/.snapshots               /dev/nvme0n1p2[/@snapshots]   btrfs   rw,noatime,...
├─/home                     /dev/nvme0n1p2[/@home]        btrfs   rw,noatime,...
├─/swap                     /dev/nvme0n1p2[/@swap]        btrfs   rw,noatime,...
├─/var/log                  /dev/nvme0n1p2[/@log]         btrfs   rw,noatime,...
├─/var/cache/pacman/pkg     /dev/nvme0n1p2[/@pkg]         btrfs   rw,noatime,...
└─/var/lib/docker           /dev/nvme0n1p2[/@docker]      btrfs   rw,noatime,...
```

Confirma que los servicios de snapper están activos:

```bash
systemctl is-enabled snapper-timeline.timer snapper-cleanup.timer grub-btrfsd
```

Resultado esperado:

```text
enabled
enabled
enabled
```

Confirma que `grub-btrfsd` regeneró las entradas de snapshots:

```bash
systemctl status grub-btrfsd | grep "Grub submenu"
```

Resultado esperado (después de que snap-pac haya creado al menos un snapshot):

```text
grub-btrfsd[...]: Grub submenu recreated
```

> **Nota**: Los snapshots aparecen en el menú de GRUB a partir del **segundo arranque**. En el primer arranque `grub-btrfs.cfg` todavía está vacío — `grub-btrfsd` lo genera durante ese primer arranque. Al reiniciar nuevamente, GRUB ya lo lee correctamente y muestra el submenú de snapshots.

Confirma que el nombre del submenú de snapshots en GRUB es correcto:

```bash
grep -i "snapshots" /boot/grub/grub.cfg | head -3
```

Resultado esperado:

```text
submenu 'CachyOS Snapshots' ...
```

Si el resultado muestra `Arch Linux Snapshots` en lugar de `CachyOS Snapshots`, significa que `grub-mkconfig` se ejecutó antes de configurar `GRUB_BTRFS_SUBMENUNAME`. Corrígelo con:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Confirma que la red está activa:

```bash
ping -c 3 archlinux.org
```

---

## Estado esperado al final del capítulo

Al terminar este capítulo:

- El sistema arranca desde el disco instalado con el kernel de CachyOS.
- Todos los subvolúmenes BTRFS están montados según el `fstab`.
- Los servicios de snapper y `grub-btrfsd` están activos.
- El submenú de snapshots en GRUB se llama "CachyOS Snapshots".
- La red funciona.

El siguiente capítulo cubre la resolución de problemas comunes y el procedimiento de rollback en caso de emergencia.

---

← [Cap. 09 — Verificación de Snapshots](Capítulo-09-Verificacion-de-Snapshots.md) · [Índice](..) · [Cap. 11 — Rollback](Capítulo-11-Rollback.md) →
