← [Cap. 01 — Fundamentos de BTRFS](Capítulo-01-Fundamentos-de-Snapshots-y-Rollbacks-en-BTRFS.md) · [Índice](..) · [Cap. 03 — Instalación base](Capítulo-03-Instalación-base-con-pacstrap.md) →

---

## Instalación automatizada (opción recomendada)

Si prefieres no ejecutar los pasos manualmente, el script `install-base.sh` automatiza todo lo que cubren los capítulos 2 al 10: particionado, subvolúmenes BTRFS, pacstrap, GRUB, snapper y creación del usuario.

Desde el Live USB, copia el script desde tu otra máquina via SCP (el Live USB de CachyOS arranca `sshd` automáticamente):

```bash
# Desde tu estación de trabajo — reemplaza la IP por la del Live USB
scp install-base.sh root@IP:/root/
```

Conéctate al Live USB y ejecútalo:

```bash
ssh root@IP
bash /root/install-base.sh
```

El script preguntará los parámetros de instalación uno por uno:

- **Disco destino** — muestra una lista numerada con todos los discos detectados (nombre, tamaño y modelo); basta con escribir el número. No se escribe la ruta manualmente.
- **Hostname**, usuario y contraseña
- **Zona horaria** y locale
- **Cifrado LUKS2** (opcional)
- **Tamaño de swap** (calculado según RAM e hibernación)
- **Subvolumen Docker** (opcional)

El resto es completamente automático.

Al terminar, el sistema está listo para reiniciar. Continúa en el **Capítulo 12** con `install-cachyos-hyprland.sh`.

> **Si el script aborta sin mostrar el banner de éxito**, imprimirá la línea exacta y el comando que fallaron. El detalle completo queda en el log junto al script:
> ```
> install-base.log
> ```

---

Si prefieres entender y ejecutar el proceso paso a paso, continúa con las secciones siguientes. El proceso manual es equivalente a lo que hace el script, y es útil para diagnóstico o configuraciones especiales.

---

En este capítulo prepararemos el disco desde el entorno Live USB de CachyOS.

El resultado será:

- Una partición EFI en FAT32 montada luego como `/efi`.
- Una partición BTRFS que contendrá el pool principal.
- Los subvolúmenes BTRFS necesarios para el sistema:
  - `@`
  - `@home`
  - `@log`
  - `@snapshots`
  - `@pkg`
  - `@swap`
  - `@docker` (opcional, solo si usas Docker)
- El sistema montado correctamente en `/mnt`, listo para instalar CachyOS en el siguiente capítulo.

> Advertencia: los comandos de este capítulo destruyen el contenido del disco seleccionado. Verifica varias veces el nombre del disco antes de continuar.

## 1. Preparar y validar acceso SSH al Live USB

Este paso es necesario si vas a ejecutar la instalación desde otra máquina usando SSH. Es una forma cómoda y segura de copiar comandos, revisar salidas y documentar errores sin depender solamente de la pantalla del portátil.

Si vas a trabajar directamente en la terminal local del Live USB, puedes omitir la conexión SSH, pero igualmente asegúrate de ejecutar los comandos de este capítulo como `root`.

Primero conviértete en `root` desde la terminal local del Live USB:

```bash
sudo su -
```

Verifica que ya estás trabajando como `root`:

```bash
whoami
```

Debe responder:

```text
root
```

Ahora verifica que el Live USB tiene red:

```bash
ip -br addr
```

Busca una interfaz con una dirección IP. En una red doméstica suele verse algo como:

```text
wlan0            UP             IP/24
```

En este ejemplo, la IP del Live USB sería:

```text
IP
```

Asigna una contraseña temporal al usuario `root`. Esa será la contraseña que usarás para entrar por SSH.

```bash
passwd
```

Cuando `passwd` lo pida, escribe una contraseña temporal. No uses una contraseña importante ni personal; esta contraseña solo sirve durante la sesión del Live USB.

Desde tu otra computadora, conéctate al Live USB. Reemplaza `IP` por la IP real que viste con `ip -br addr`:

```bash
ssh root@IP
```

Acepta la huella del host si es la primera conexión y escribe la contraseña temporal que configuraste con `passwd`.

Dentro de la sesión SSH, valida que sigues siendo `root`:

```bash
whoami
```

Debe responder:

```text
root
```

A partir de este punto, si estás conectado por SSH, continúa el capítulo dentro de esa sesión.

## 2. Verificar que el Live USB arrancó en modo UEFI

Antes de particionar, confirma que el sistema Live está arrancado en modo UEFI:

```bash
ls /sys/firmware/efi/efivars
```

Si el comando muestra muchos archivos, estás en modo UEFI.

Si aparece un error indicando que la ruta no existe, el Live USB arrancó en modo BIOS/Legacy. En ese caso, reinicia y selecciona explícitamente la entrada UEFI del USB desde el menú de arranque del firmware. Después de reiniciar, repite la preparación SSH si vas a trabajar de forma remota.

## 3. Identificar el disco de destino

Lista los discos disponibles:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
```

En una laptop moderna, el disco interno suele llamarse algo como:

```text
/dev/nvme0n1
```

En este capítulo usaremos `/dev/nvme0n1` como ejemplo.

Si tu disco tiene otro nombre, reemplázalo en todos los comandos siguientes.

Define una variable para reducir errores:

```bash
DISK=/dev/nvme0n1
```

Verifica que la variable apunta al disco correcto:

```bash
echo "$DISK"
lsblk "$DISK"
```

No continúes si no estás completamente seguro de que ese es el disco correcto.

## 4. Limpiar la tabla de particiones anterior

Eliminaremos las estructuras de particionado existentes del disco.

```bash
sgdisk --zap-all "$DISK"
```

También conviene borrar firmas antiguas de sistemas de archivos:

```bash
wipefs -af "$DISK"
```

Vuelve a consultar el estado del disco:

```bash
lsblk "$DISK"
```

En este punto el disco debería aparecer sin particiones útiles.

## 5. Crear las particiones

Crearemos dos particiones:

- Partición 1: EFI, 1 GiB, tipo `ef00`.
- Partición 2: BTRFS, resto del disco, tipo `8300`.

```bash
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:EFI "$DISK"
sgdisk -n 2:0:0   -t 2:8300 -c 2:BTRFS "$DISK"
```

Forzamos al kernel a releer la tabla de particiones:

```bash
partprobe "$DISK"
```

Verifica el resultado:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL "$DISK"
```

Deberías ver algo parecido a:

```text
nvme0n1       disk
├─nvme0n1p1   1G part        EFI
└─nvme0n1p2      part        BTRFS
```

## 6. Definir variables para las particiones

En discos NVMe, las particiones se nombran con `p1`, `p2`, etc.

```bash
EFI_PART="${DISK}p1"
BTRFS_PART="${DISK}p2"
```

Verifica:

```bash
echo "$EFI_PART"
echo "$BTRFS_PART"
lsblk "$DISK"
```

Si estás usando un disco SATA como `/dev/sda`, las particiones serían `/dev/sda1` y `/dev/sda2`. En ese caso, define manualmente:

```bash
EFI_PART=/dev/sda1
BTRFS_PART=/dev/sda2
```

## 7. Formatear la partición EFI

La partición EFI debe estar en FAT32:

```bash
mkfs.vfat -F 32 -n EFI "$EFI_PART"
```

Esta partición será montada más adelante en `/efi`.

## 8. Formatear la partición BTRFS

Ahora formateamos la segunda partición como BTRFS:

```bash
mkfs.btrfs -f -L CachyOS "$BTRFS_PART"
```

La etiqueta `CachyOS` no es obligatoria, pero ayuda a identificar el sistema más adelante.

Verifica:

```bash
lsblk -f "$DISK"
```

## 9. Montar temporalmente el pool BTRFS

Para crear subvolúmenes, primero montamos la raíz del sistema de archivos BTRFS:

```bash
mount "$BTRFS_PART" /mnt
```

Comprueba que está montado:

```bash
mount | grep /mnt
```

## 10. Crear los subvolúmenes BTRFS

Crea los subvolúmenes acordados:

```bash
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@pkg
btrfs subvolume create /mnt/@swap
btrfs subvolume create /mnt/@docker
```

Verifica la lista:

```bash
btrfs subvolume list /mnt
```

Deberías ver los siete subvolúmenes recién creados (incluyendo `@docker`). Si no usas Docker, puedes omitir ese subvolumen.

## 11. Desmontar el pool temporal

Una vez creados los subvolúmenes, desmontamos el pool para volver a montarlo con la estructura definitiva:

```bash
umount /mnt
```

## 12. Montar el sistema definitivo en /mnt

Usaremos estas opciones BTRFS:

- `compress=zstd`: compresión transparente con Zstandard.
- `noatime`: evita escrituras innecesarias al leer archivos.
- `ssd`: optimización para discos SSD/NVMe.

Define las opciones en una variable:

```bash
BTRFS_OPTS="noatime,compress=zstd,ssd"
```

Monta el subvolumen raíz `@` en `/mnt`:

```bash
mount -o "$BTRFS_OPTS",subvol=@ "$BTRFS_PART" /mnt
```

Crea los puntos de montaje:

```bash
mkdir -p /mnt/{efi,home,var/log,var/cache,var/lib/docker,var/lib/containerd}
```

Monta la partición EFI en `/mnt/efi`:

```bash
mount "$EFI_PART" /mnt/efi
```

Monta el resto de subvolúmenes:

```bash
mount -o "$BTRFS_OPTS",subvol=@home "$BTRFS_PART" /mnt/home
mount -o "$BTRFS_OPTS",subvol=@log "$BTRFS_PART" /mnt/var/log
mount -o "$BTRFS_OPTS",subvol=@snapshots "$BTRFS_PART" /mnt/.snapshots
mount -o "$BTRFS_OPTS",subvol=@pkg "$BTRFS_PART" /mnt/var/cache/pacman/pkg
mount -o "rw,noatime,nodatacow,subvol=@swap" "$BTRFS_PART" /mnt/swap
mount -o "$BTRFS_OPTS",subvol=@docker "$BTRFS_PART" /mnt/var/lib/docker
```

No se crea una partición separada para `/boot`.

`/boot` vivirá dentro del subvolumen `@`, por lo tanto quedará incluido en los snapshots del sistema. Esto es importante para que los kernels y el sistema base puedan retroceder juntos durante un rollback.

## 13. Verificación final

Revisa la estructura de bloques:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$DISK"
```

Deberías ver algo como esto (los tamaños variarán según tu disco):

```text
NAME          SIZE FSTYPE LABEL   MOUNTPOINTS
nvme0n1     476.9G
├─nvme0n1p1     1G vfat   EFI     /mnt/efi
└─nvme0n1p2 475.9G btrfs  CachyOS /mnt/var/lib/docker
                                  /mnt/var/cache/pacman/pkg
                                  /mnt/swap
                                  /mnt/var/log
                                  /mnt/.snapshots
                                  /mnt/home
                                  /mnt
```

Es normal que `nvme0n1p2` aparezca una sola vez aunque esté montada en varios puntos. BTRFS es una sola partición física cuyos subvolúmenes pueden montarse de forma independiente. Cada línea de `MOUNTPOINTS` corresponde a uno de los subvolúmenes creados.

Verifica los montajes relacionados con el disco NVMe:

```bash
mount | grep nvme
```

También puedes verificar específicamente los subvolúmenes BTRFS montados:

```bash
findmnt -R /mnt
```

La salida debe mostrar una estructura parecida a esta (las opciones largas están truncadas por ancho de terminal):

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

Cada subvolumen aparece con su nombre entre corchetes junto al dispositivo fuente, por ejemplo `[/@home]`. Las opciones `discard=async` y `space_cache=v2` las agrega BTRFS automáticamente al detectar un disco SSD — son correctas y beneficiosas, no es necesario especificarlas manualmente.

## Estado esperado al final del capítulo

Al terminar este capítulo:

- El disco tiene una tabla GPT limpia.
- Existe una partición EFI de 1 GiB en FAT32.
- Existe una partición BTRFS para el sistema.
- Los subvolúmenes BTRFS necesarios ya fueron creados.
- El sistema está montado en `/mnt`.
- `/efi` está preparado como punto de montaje para la partición EFI.
- `/boot` queda dentro del subvolumen raíz `@`.

Con esto, el sistema está listo para instalar la base de CachyOS en el siguiente capítulo.

---

← [Cap. 01 — Fundamentos de BTRFS](Capítulo-01-Fundamentos-de-Snapshots-y-Rollbacks-en-BTRFS.md) · [Índice](..) · [Cap. 03 — Instalación base](Capítulo-03-Instalación-base-con-pacstrap.md) →
