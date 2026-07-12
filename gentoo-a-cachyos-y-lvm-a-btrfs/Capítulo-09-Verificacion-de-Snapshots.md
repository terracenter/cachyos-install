← [Cap. 08 — mkinitcpio](Capítulo-08-mkinitcpio.md) · [Índice](..) · [Cap. 10 — Primer arranque](Capítulo-10-Primer-arranque.md) →

---

En este capítulo se confirma que la infraestructura de snapshots está correctamente configurada: snapper lista los snapshots y el pool BTRFS los muestra en la ruta esperada.

> Todos los comandos de este capítulo se ejecutan **dentro del chroot**.

---

## 1. Listar snapshots disponibles

```bash
snapper --no-dbus -c root list
```

Resultado esperado:

```text
 # │ Type   │ Pre # │ Date                     │ User │ Cleanup │ Description                          │ Userdata
───┼────────┼───────┼──────────────────────────┼──────┼─────────┼──────────────────────────────────────┼─────────
 0 │ single │       │                          │ root │         │ current                              │
 1 │ single │       │ Sat May 16 19:34:50 2026 │ root │         │ sistema base limpio post-instalacion │
```

El snapshot `0` es el estado actual (no es un snapshot real). El `1` es el que creaste en el Capítulo 6.

---

## 2. Verificar el pool BTRFS

Monta el nivel raíz del pool:

```bash
mkdir -p /tmp/btrfs
mount -o subvolid=5 /dev/nvme0n1p2 /tmp/btrfs
```

> El mensaje `systemctl daemon-reload` que puede aparecer al montar es inofensivo en entorno chroot. No requiere ninguna acción.

Verifica que el snapshot aparece bajo `@snapshots`:

```bash
btrfs subvolume list /tmp/btrfs
```

Resultado esperado (los IDs varían según el sistema):

```text
ID 256 gen 64 top level 5 path @
ID 257 gen 30 top level 5 path @home
ID 258 gen 26 top level 5 path @log
ID 259 gen 26 top level 5 path @snapshots
ID 260 gen 9  top level 5 path @pkg
ID 261 gen 9  top level 5 path @swap
ID 262 gen 50 top level 5 path @docker
ID 263 gen 18 top level 256 path @/var/lib/portables
ID 264 gen 18 top level 256 path @/var/lib/machines
ID 268 gen 49 top level 259 path @snapshots/1/snapshot
```

Los snapshots de snapper aparecen bajo `@snapshots/<N>/snapshot`. El número `N` corresponde al ID en `snapper list`.

Desmonta el pool temporal:

```bash
umount /tmp/btrfs
```

---

## Estado esperado al final del capítulo

Al terminar este capítulo:

- Existe al menos un snapshot (`#1`) verificado en `snapper list`.
- El pool BTRFS muestra el snapshot bajo `@snapshots/1/snapshot`.

El siguiente capítulo cubre el primer arranque: salir del chroot, desmontar y reiniciar en el sistema instalado.

---

← [Cap. 08 — mkinitcpio](Capítulo-08-mkinitcpio.md) · [Índice](..) · [Cap. 10 — Primer arranque](Capítulo-10-Primer-arranque.md) →
