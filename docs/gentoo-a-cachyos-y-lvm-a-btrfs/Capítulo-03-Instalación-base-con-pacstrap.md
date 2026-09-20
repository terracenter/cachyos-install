← [Cap. 02 — Particionado y montaje](Capítulo-02-Particionado-y-montaje-desde-el-Live-USB.md) · [Índice](..) · [Cap. 04 — Repositorios CachyOS](Capítulo-04-Repositorios-CachyOS.md) →

---

En este capítulo instalaremos el sistema base de CachyOS en la estructura BTRFS que preparamos en el capítulo anterior. Al finalizar, el nuevo sistema tendrá todos los paquetes necesarios para arrancar, gestionar snapshots y actualizar GRUB automáticamente.

> Este capítulo se ejecuta desde el entorno Live USB, como `root`, con `/mnt` montado según el capítulo 2.

---

## 1. Verificar el entorno de trabajo

Si tu sesión SSH se interrumpió o abriste una nueva terminal, redefine las variables antes de continuar:

```bash
DISK=/dev/nvme0n1
EFI_PART="${DISK}p1"
BTRFS_PART="${DISK}p2"
BTRFS_OPTS="noatime,compress=zstd,ssd"
```

Verifica que `/mnt` sigue montado correctamente:

```bash
findmnt -R /mnt
```

En este punto la salida debe coincidir con el estado final del capítulo 2. El subvolumen `@snapshots` **aún no existe** — se crea en el paso 3 de este capítulo. Lo siguiente es la salida esperada ahora:

```text
TARGET                              SOURCE                     FSTYPE  OPTIONS
/mnt                                /dev/nvme0n1p2[/@]         btrfs   rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,...
├─/mnt/.snapshots                   /dev/nvme0n1p2[/@snapshots] btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,...
├─/mnt/efi                          /dev/nvme0n1p1             vfat    rw,relatime,...
├─/mnt/home                         /dev/nvme0n1p2[/@home]     btrfs   rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,...
├─/mnt/swap                         /dev/nvme0n1p2[/@swap]     btrfs   rw,noatime,nodatacow,space_cache=v2,...
├─/mnt/var/log                      /dev/nvme0n1p2[/@log]      btrfs   rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,...
├─/mnt/var/cache/pacman/pkg         /dev/nvme0n1p2[/@pkg]      btrfs   rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,...
└─/mnt/var/lib/docker               /dev/nvme0n1p2[/@docker]   btrfs   rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,...
```

Si no hay nada montado en `/mnt`, regresa al capítulo 2 y ejecuta nuevamente la sección de montaje definitivo.

---

## 2. Verificar conectividad de red

```bash
ping -c 3 archlinux.org
```

Resultado esperado: tres respuestas con tiempo de ida y vuelta (ms). Si no hay respuesta, verifica que el Wi-Fi o cable estén activos antes de continuar.

---

## 3. Crear el subvolumen @snapshots

Este subvolumen es necesario para que **snapper** almacene los snapshots fuera del árbol principal `@`. Si los snapshots quedaran dentro de `@`, serían incluidos en cada snapshot del sistema, lo que generaría un crecimiento exponencial del espacio utilizado.

Para crearlo debemos acceder al nivel raíz del sistema de archivos BTRFS (subvolid=5), que en este momento no está montado directamente. Primero crea el directorio temporal de montaje:

```bash
mkdir -p /tmp/btrfs-top
```

Luego monta el nivel raíz BTRFS ahí:

```bash
mount -o subvolid=5 "$BTRFS_PART" /tmp/btrfs-top
```

Crea el subvolumen:

```bash
btrfs subvolume create /tmp/btrfs-top/@snapshots
```

Desmonta el nivel raíz temporal:

```bash
umount /tmp/btrfs-top
```

Crea el punto de montaje dentro del sistema destino:

```bash
mkdir /mnt/.snapshots
```

Monta el subvolumen `@snapshots` en `/.snapshots`:

```bash
mount -o "$BTRFS_OPTS",subvol=@snapshots "$BTRFS_PART" /mnt/.snapshots
```

Verifica el montaje:

```bash
findmnt /mnt/.snapshots
```

Resultado esperado:

```text
TARGET          SOURCE                        FSTYPE  OPTIONS
/mnt/.snapshots /dev/nvme0n1p2[/@snapshots]   btrfs   rw,noatime,compress=zstd:3,ssd,...
```

---

## 4. Verificar estructura de subvolúmenes completa

Con `@snapshots` ya montado, la estructura definitiva en `/mnt` debe ser:

```bash
findmnt -R /mnt
```

Resultado esperado:

```text
TARGET                              SOURCE                          FSTYPE
/mnt                                /dev/nvme0n1p2[/@]              btrfs
├─/mnt/.snapshots                   /dev/nvme0n1p2[/@snapshots]     btrfs
├─/mnt/efi                          /dev/nvme0n1p1                  vfat
├─/mnt/home                         /dev/nvme0n1p2[/@home]          btrfs
├─/mnt/swap                         /dev/nvme0n1p2[/@swap]          btrfs
├─/mnt/var/log                      /dev/nvme0n1p2[/@log]           btrfs
├─/mnt/var/cache/pacman/pkg         /dev/nvme0n1p2[/@pkg]           btrfs
└─/mnt/var/lib/docker               /dev/nvme0n1p2[/@docker]        btrfs
```

---

## 5. Actualizar los keyrings

Antes de instalar paquetes, actualiza los keyrings para evitar errores de firma durante la instalación:

```bash
pacman -Sy --noconfirm archlinux-keyring cachyos-keyring
```

| Paquete | Propósito |
|---|---|
| `archlinux-keyring` | Claves GPG oficiales de Arch Linux para verificar la firma de los paquetes del repositorio base |
| `cachyos-keyring` | Claves GPG de CachyOS para verificar los paquetes de sus repositorios propios |

---

## 6. Instalar el sistema base con pacstrap

El siguiente comando instala todos los paquetes necesarios para el sistema, incluyendo el kernel de CachyOS, las herramientas BTRFS, GRUB con soporte para snapshots, snapper y sus hooks para pacman:

```bash
pacstrap -K /mnt \
    base base-devel \
    linux-cachyos linux-cachyos-headers \
    linux-firmware intel-ucode \
    btrfs-progs dosfstools \
    grub efibootmgr \
    grub-btrfs inotify-tools \
    snapper snap-pac \
    networkmanager \
    vim sudo git curl rsync
```

Descripción de todos los paquetes instalados:

| Paquete | Categoría | Propósito |
|---|---|---|
| `base` | Sistema | Núcleo mínimo del sistema: systemd, pacman, bash, coreutils |
| `base-devel` | Sistema | Herramientas de compilación: gcc, make, etc. Necesarias para AUR y DKMS |
| `linux-cachyos` | Kernel | Kernel de CachyOS con scheduler BORE, optimizado para baja latencia |
| `linux-cachyos-headers` | Kernel | Cabeceras del kernel, requeridas para módulos externos y DKMS |
| `linux-firmware` | Firmware | Firmware para hardware diverso, incluye Intel WiFi (`iwlwifi`) y GPUs |
| `intel-ucode` | Firmware | Microcódigos del procesador Intel — corrige bugs de CPU en tiempo de arranque. Para AMD usar `amd-ucode` |
| `dosfstools` | Filesystem | Utilidades FAT32: `mkfs.vfat`, `fsck.vfat`. Necesarias para gestionar la partición EFI |
| `efibootmgr` | Arranque | Gestiona las entradas de arranque en la NVRAM del firmware UEFI |
| `inotify-tools` | Arranque | Monitoreo de cambios en el sistema de archivos. Requerido por el daemon `grub-btrfsd` para detectar nuevos snapshots y actualizar GRUB automáticamente |
| `networkmanager` | Red | Gestión de red con soporte para WiFi, Ethernet y VPN. Se habilita en el Capítulo 5 |
| `vim` | Herramientas | Editor de texto en terminal |
| `sudo` | Herramientas | Permite ejecutar comandos como root de forma controlada y auditable |
| `git` | Herramientas | Control de versiones |
| `curl` | Herramientas | Transferencia de datos HTTP/HTTPS desde la terminal |
| `rsync` | Herramientas | Sincronización eficiente de archivos y directorios, local y remota |

> `mkinitcpio` se ejecutará automáticamente durante `pacstrap` al instalar el kernel. El initramfs generado en este paso será reemplazado en el Capítulo 8, cuando se agregue el hook `btrfs`. No es necesario intervenir ahora.

> Al finalizar la instalación, es normal ver el siguiente mensaje:
>
> ```text
> Performing snapper post snapshots for the following configurations...
> fatal library error, lookup self
> ```
>
> Este aviso lo genera `snap-pac` al disparar su hook de pacman durante la instalación. Como snapper aún no tiene ninguna configuración creada, falla internamente pero sin afectar la instalación. Desaparecerá después del Capítulo 6, cuando se configure snapper correctamente.

La instalación puede tardar varios minutos dependiendo de la velocidad de la red y del disco.

---

## 7. Generar el fstab

El archivo `/etc/fstab` define cómo se montan las particiones y subvolúmenes en el arranque. Genéralo a partir de los montajes actuales:

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

---

## 8. Eliminar subvolid del fstab

Este paso es **crítico para que los rollbacks funcionen correctamente**.

`genfstab` incluye la opción `subvolid=` junto con `subvol=@` en cada entrada BTRFS. El `subvolid` es un identificador numérico interno que cambia cuando se realiza un rollback a un snapshot. Si `subvolid=` permanece en el fstab, el sistema no arrancará después de un rollback porque buscará un ID que ya no coincide.

Verifica que el problema existe antes de corregirlo:

```bash
grep subvolid /mnt/etc/fstab
```

Si el comando muestra líneas con `subvolid=`, elimínalos:

```bash
sed -i 's/,subvolid=[0-9]*//' /mnt/etc/fstab
```

Verifica que no quedan entradas con `subvolid`:

```bash
grep subvolid /mnt/etc/fstab
```

No debe mostrar ninguna salida.

---

## 9. Verificar el fstab completo

```bash
cat /mnt/etc/fstab
```

El archivo debe tener una entrada por cada subvolumen montado. La siguiente salida fue validada en hardware real y es la referencia de cómo debe verse:

```text
# Static information about the filesystems.
# See fstab(5) for details.

# <file system> <dir> <type> <options> <dump> <pass>
# /dev/nvme0n1p2 LABEL=CachyOS
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /                   btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@            0 0

# /dev/nvme0n1p1 LABEL=EFI
UUID=XXXX-XXXX                             /efi                vfat   rw,relatime,fmask=0022,dmask=0022,codepage=437,iocharset=ascii,...               0 2

# /dev/nvme0n1p2 LABEL=CachyOS
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /home               btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@home        0 0

# /dev/nvme0n1p2 LABEL=CachyOS
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /var/log            btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@log         0 0

# /dev/nvme0n1p2 LABEL=CachyOS (swap — COW deshabilitado)
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /swap                           btrfs  rw,noatime,nodatacow,space_cache=v2,subvol=/@swap            0 0

# /dev/nvme0n1p2 LABEL=CachyOS
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /var/cache/pacman/pkg           btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@pkg        0 0

# /dev/nvme0n1p2 LABEL=CachyOS
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /var/lib/docker                 btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@docker      0 0

# /dev/nvme0n1p2 LABEL=CachyOS
UUID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  /.snapshots                     btrfs  rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@snapshots   0 0
```

Verifica que:

- Existen las 8 entradas: `/`, `/efi`, `/home`, `/var/log`, `/swap`, `/var/cache/pacman/pkg`, `/var/lib/docker`, `/.snapshots`.
- Todas las entradas BTRFS tienen `subvol=/@nombre` correcto.
- La partición EFI tiene tipo `vfat` y punto de montaje `/efi`.
- Ninguna entrada contiene `subvolid=`.

---

## 10. Entrar al entorno chroot

A partir de este punto, todos los comandos de los capítulos siguientes se ejecutan **dentro del sistema instalado**, no en el Live USB:

```bash
arch-chroot /mnt
```

El prompt cambiará para indicar que estás dentro del chroot. Dependiendo de la configuración del Live USB, puede verse algo como:

```text
[root@cachyos /]#
```

---

## 11. Verificar el entorno chroot

Confirma que el kernel de CachyOS está instalado:

```bash
uname -r
```

La salida debe mostrar un nombre de kernel con `cachyos`, por ejemplo:

```text
6.x.x-cachyos
```

Verifica que los paquetes clave están instalados:

```bash
pacman -Q snapper snap-pac grub grub-btrfs btrfs-progs
```

Debes ver una línea por cada paquete con su versión, sin errores de "not found".

| Paquete | Propósito |
|---|---|
| `snapper` | Motor de snapshots BTRFS — crea, lista, elimina y programa puntos de restauración |
| `snap-pac` | Hooks de pacman — dispara snapper antes y después de cada operación de paquetes (`-S`, `-Syu`, `-R`), generando pares pre/post automáticamente |
| `grub` | Gestor de arranque principal del sistema |
| `grub-btrfs` | Genera entradas en el menú de GRUB por cada snapshot BTRFS disponible, permitiendo arrancar desde uno |
| `btrfs-progs` | Utilidades de administración BTRFS: `mkfs.btrfs`, `btrfs balance`, `btrfs scrub`, `btrfs subvolume` |

---

## Estado esperado al final del capítulo

Al terminar este capítulo:

- El subvolumen `@snapshots` fue creado y está montado en `/.snapshots`.
- El sistema base de CachyOS está instalado en `/mnt`.
- El kernel `linux-cachyos` está presente junto con sus headers.
- `snapper` y `snap-pac` están instalados para la gestión automática de snapshots.
- `grub-btrfs` e `inotify-tools` están instalados para la integración GRUB/snapshots.
- El archivo `/etc/fstab` fue generado y limpiado de entradas `subvolid`.
- Estás dentro del chroot del nuevo sistema.

El siguiente capítulo configura los repositorios oficiales de CachyOS — paso obligatorio antes de continuar con la configuración del sistema.

---

← [Cap. 02 — Particionado y montaje](Capítulo-02-Particionado-y-montaje-desde-el-Live-USB.md) · [Índice](..) · [Cap. 04 — Repositorios CachyOS](Capítulo-04-Repositorios-CachyOS.md) →
