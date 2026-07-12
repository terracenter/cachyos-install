← [Cap. 05 — Configuración del sistema](Capítulo-05-Configuración-del-sistema.md) · [Índice](..) · [Cap. 07 — Configuración de GRUB](Capítulo-07-Configuración-de-GRUB.md) →

---

En este capítulo configuramos snapper para gestionar snapshots BTRFS automáticamente. Al finalizar, el sistema creará snapshots antes y después de cada operación de pacman, y también por calendario (cada hora, cada día).

> Todos los comandos de este capítulo se ejecutan **dentro del chroot**.

---

## 1. Crear la configuración de snapper para la raíz

Snapper necesita una configuración por cada subvolumen que va a gestionar. La creación de la configuración implica un procedimiento especial porque ya existe `@snapshots` montado en `/.snapshots`.

**Por qué es necesario este procedimiento:** snapper intenta crear un subvolumen BTRFS en `/.snapshots` durante `create-config`. Como ese directorio ya está ocupado por el montaje de `@snapshots`, falla con `errno:17 (File exists)`. La solución es desmontarlo temporalmente, dejar que snapper cree su configuración y el subvolumen, eliminar ese subvolumen interno, y volver a montar `@snapshots`.

Además, dentro del entorno chroot D-Bus no está en ejecución, por lo que es obligatorio usar el flag `--no-dbus` en todos los comandos de snapper.

> **Nota:** `create-config` registra el nombre del config en `/etc/conf.d/snapper` (clave `SNAPPER_CONFIGS`), además de crear el archivo `/etc/snapper/configs/root`. Si alguna vez necesitas rehacer este paso, usa `snapper --no-dbus -c root delete-config` — no borres el archivo manualmente, ya que eso deja el registro en `/etc/conf.d/snapper` y el siguiente `create-config` fallará con `config already exists`.

Desmonta `/.snapshots` temporalmente:

```bash
umount /.snapshots
```

Elimina el directorio vacío:

```bash
rmdir /.snapshots
```

Crea la configuración de snapper. Esta vez sí tendrá éxito porque el directorio ya no existe:

```bash
snapper --no-dbus -c root create-config /
```

Snapper habrá creado un subvolumen `.snapshots` dentro de `@`. Elimínalo — usaremos `@snapshots` en su lugar:

```bash
btrfs subvolume delete /.snapshots
```

Resultado esperado:

```text
Delete subvolume 265 (no-commit): '//.snapshots'
```

Recrea el directorio vacío y monta `@snapshots`. Sustituye `/dev/DISCO_BTRFS` por la partición BTRFS del equipo (ej. `/dev/nvme0n1p2` en NVMe, `/dev/sda2` en SATA):

```bash
mkdir /.snapshots
mount -o noatime,compress=zstd,ssd,subvol=@snapshots /dev/DISCO_BTRFS /.snapshots
```

> El mensaje `systemctl daemon-reload` que puede aparecer al montar es inofensivo en el entorno chroot. No requiere ninguna acción.

Este comando crea el archivo `/etc/snapper/configs/root` con los parámetros por defecto.

> Una vez arrancado el sistema real, snapper funciona con normalidad sin el flag `--no-dbus`.

Verifica que el archivo fue creado:

```bash
cat /etc/snapper/configs/root
```

---

## 2. Verificar el punto de montaje /.snapshots

Después de crear la configuración, confirma que `/.snapshots` sigue siendo el subvolumen `@snapshots` que montamos en el Capítulo 3 y no fue reemplazado por snapper:

```bash
findmnt /.snapshots
```

Resultado esperado:

```text
TARGET        SOURCE                        FSTYPE  OPTIONS
/.snapshots   /dev/nvme0n1p2[/@snapshots]   btrfs   rw,noatime,...
```

Si el resultado muestra `[/@snapshots]`, está correcto.

---

## 3. Ajustar permisos de /.snapshots

Por defecto snapper crea el directorio con permisos restrictivos. Asigna el grupo `sudo` como propietario de grupo y ajusta los permisos para que los miembros del grupo puedan listar snapshots sin necesidad de root:

```bash
chmod 750 /.snapshots
chown :sudo /.snapshots
```

Verifica:

```bash
ls -la / | grep snapshots
```

Resultado esperado:

```text
drwxr-x---  1 root sudo  ... .snapshots
```

---

## 4. Configurar los parámetros de retención

Aplica los valores de retención con `sed`:

```bash
sed -i \
  -e 's/ALLOW_GROUPS=""/ALLOW_GROUPS="sudo"/' \
  -e 's/NUMBER_MIN_AGE="3600"/NUMBER_MIN_AGE="1800"/' \
  -e 's/TIMELINE_MIN_AGE="3600"/TIMELINE_MIN_AGE="1800"/' \
  -e 's/TIMELINE_LIMIT_HOURLY="10"/TIMELINE_LIMIT_HOURLY="5"/' \
  -e 's/TIMELINE_LIMIT_DAILY="10"/TIMELINE_LIMIT_DAILY="7"/' \
  -e 's/TIMELINE_LIMIT_WEEKLY="0"/TIMELINE_LIMIT_WEEKLY="2"/' \
  -e 's/TIMELINE_LIMIT_MONTHLY="10"/TIMELINE_LIMIT_MONTHLY="1"/' \
  -e 's/TIMELINE_LIMIT_YEARLY="10"/TIMELINE_LIMIT_YEARLY="0"/' \
  /etc/snapper/configs/root
```

Verifica los valores modificados:

```bash
grep -E 'ALLOW_GROUPS|NUMBER_MIN_AGE|TIMELINE_LIMIT|TIMELINE_MIN_AGE' /etc/snapper/configs/root
```

Resultado esperado:

```text
ALLOW_GROUPS="sudo"
NUMBER_MIN_AGE="1800"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="2"
TIMELINE_LIMIT_MONTHLY="1"
TIMELINE_LIMIT_QUARTERLY="0"
TIMELINE_LIMIT_YEARLY="0"
```

Descripción de los parámetros clave:

| Parámetro | Valor | Descripción |
|---|---|---|
| `ALLOW_GROUPS` | `sudo` | Grupo autorizado a usar snapper sin privilegios de root |
| `NUMBER_CLEANUP` | `yes` | Activa la limpieza automática de snapshots pre/post |
| `NUMBER_LIMIT` | `50` | Máximo de snapshots numerados a conservar |
| `NUMBER_LIMIT_IMPORTANT` | `10` | Máximo de snapshots marcados como importantes |
| `TIMELINE_CREATE` | `yes` | Activa los snapshots automáticos por calendario |
| `TIMELINE_CLEANUP` | `yes` | Activa la limpieza automática de snapshots de calendario |
| `TIMELINE_LIMIT_HOURLY` | `5` | Snapshots por hora a conservar |
| `TIMELINE_LIMIT_DAILY` | `7` | Snapshots diarios a conservar |
| `TIMELINE_LIMIT_WEEKLY` | `2` | Snapshots semanales a conservar |
| `TIMELINE_LIMIT_MONTHLY` | `1` | Snapshots mensuales a conservar |
| `TIMELINE_LIMIT_YEARLY` | `0` | Snapshots anuales (desactivado) |

---

## 5. Habilitar los servicios de snapper

Habilita el timer que crea snapshots automáticos por calendario:

```bash
systemctl enable snapper-timeline.timer
```

Habilita el timer que limpia snapshots antiguos según las reglas de retención:

```bash
systemctl enable snapper-cleanup.timer
```

Verifica que ambos quedaron habilitados:

```bash
systemctl is-enabled snapper-timeline.timer snapper-cleanup.timer
```

Resultado esperado:

```text
enabled
enabled
```

---

## 6. Verificar los hooks de snap-pac

Los hooks de pacman que disparan snapper se instalaron con `snap-pac` en el Capítulo 3. Verifica que están presentes:

```bash
ls /usr/share/libalpm/hooks/ | grep snap
```

Resultado esperado:

```text
05-snap-pac-pre.hook
10-snap-pac-removal.hook
zz-snap-pac-post.hook
```

| Hook | Descripción |
|---|---|
| `05-snap-pac-pre.hook` | Se ejecuta antes de instalaciones y actualizaciones (`-S`, `-Syu`) — crea el snapshot **pre** |
| `10-snap-pac-removal.hook` | Se ejecuta antes de remociones (`-R`) — crea el snapshot **pre** para operaciones de desinstalación |
| `zz-snap-pac-post.hook` | Se ejecuta al finalizar cualquier operación de pacman — crea el snapshot **post** |

El prefijo numérico controla el orden de ejecución dentro del sistema de hooks de libalpm.

---

## 7. Crear un snapshot manual de prueba

Crea el primer snapshot manualmente para verificar que todo funciona:

```bash
snapper --no-dbus -c root create --description "sistema base limpio post-instalacion"
```

Lista los snapshots existentes:

```bash
snapper --no-dbus -c root list
```

Resultado esperado:

```text
 # | Type   | Pre # | Date | User | Cleanup | Description
---+--------+-------+------+------+---------+----------------------------
 0 | single |       |      | root |         | current
 1 | single |       | ...  | root |         | sistema base limpio post-instalacion
```

El snapshot `0` representa el estado actual del sistema (no es un snapshot real, es una referencia). El snapshot `1` es el que acabas de crear.

---

## Estado esperado al final del capítulo

Al terminar este capítulo:

- Snapper tiene una configuración activa para el subvolumen raíz `/`.
- `/.snapshots` está montado correctamente con permisos para el grupo `sudo`.
- Los parámetros de retención están configurados.
- Los servicios `snapper-timeline.timer` y `snapper-cleanup.timer` están habilitados.
- Los hooks de `snap-pac` están en su lugar.
- Existe al menos un snapshot manual que confirma que el sistema funciona.

El siguiente capítulo configura GRUB para que muestre los snapshots disponibles en el menú de arranque.

---

← [Cap. 05 — Configuración del sistema](Capítulo-05-Configuración-del-sistema.md) · [Índice](..) · [Cap. 07 — Configuración de GRUB](Capítulo-07-Configuración-de-GRUB.md) →
