← [Cap. 07 — Configuración de GRUB](Capítulo-07-Configuración-de-GRUB.md) · [Índice](..) · [Cap. 09 — Verificación de Snapshots](Capítulo-09-Verificacion-de-Snapshots.md) →

---

En este capítulo agregamos el hook `btrfs` al initramfs. Sin él, el sistema puede no montar correctamente la raíz BTRFS durante el arranque, especialmente después de un rollback.

> Todos los comandos de este capítulo se ejecutan **dentro del chroot**.

---

## 1. Ver la configuración actual

```bash
grep ^HOOKS /etc/mkinitcpio.conf
```

Resultado típico en CachyOS:

```text
HOOKS=(base udev autodetect microcode modconf kmod block filesystems keyboard fsck)
```

---

## 2. Agregar el hook btrfs

El hook `btrfs` debe ir antes de `filesystems`:

```bash
sed -i 's/ filesystems/ btrfs filesystems/' /etc/mkinitcpio.conf
```

Verifica el resultado:

```bash
grep ^HOOKS /etc/mkinitcpio.conf
```

Resultado esperado:

```text
HOOKS=(base udev autodetect microcode modconf kmod block btrfs filesystems keyboard fsck)
```

---

## 3. Regenerar el initramfs

```bash
mkinitcpio -P
```

El flag `-P` regenera todos los presets instalados. Para CachyOS genera los archivos del kernel `linux-cachyos`.

Resultado esperado (extracto):

```text
==> Building image from preset: /etc/mkinitcpio.d/linux-cachyos.preset: 'default'
==> Starting build: 6.x.x-cachyos
  -> Running build hook: [base]
  -> Running build hook: [udev]
  ...
  -> Running build hook: [btrfs]
  -> Running build hook: [filesystems]
  ...
==> Image generation successful
```

---

## 4. Verificar los archivos generados

```bash
ls -lh /boot/initramfs-linux-cachyos*.img
```

Resultado esperado:

```text
-rw------- 1 root root 26M  ...  /boot/initramfs-linux-cachyos.img
```

Confirma que el hook `btrfs` quedó incluido en el initramfs generado:

```bash
lsinitcpio -a /boot/initramfs-linux-cachyos.img | grep btrfs
```

Resultado esperado:

```text
btrfs
```

---

## Estado esperado al final del capítulo

Al terminar este capítulo:

- El hook `btrfs` está presente en la línea `HOOKS` de `/etc/mkinitcpio.conf`.
- El initramfs fue regenerado e incluye soporte nativo para BTRFS.

El siguiente capítulo verifica que los snapshots se crearon correctamente y que el pool BTRFS está en el estado esperado.

---

← [Cap. 07 — Configuración de GRUB](Capítulo-07-Configuración-de-GRUB.md) · [Índice](..) · [Cap. 09 — Verificación de Snapshots](Capítulo-09-Verificacion-de-Snapshots.md) →
