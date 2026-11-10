# Capítulo 02: Particionado y montaje desde el Live USB

[← Cap. 01: Fundamentos de Btrfs](Capítulo-01-Fundamentos-de-Snapshots-y-Rollbacks-en-BTRFS.md) · [Índice](../_index.md) · [Cap. 03: Instalación base →](Capítulo-03-Instalación-base-con-pacstrap.md)

## Objetivo

Este capítulo describe el particionado que realiza `base/install-base.sh` desde un Live USB de CachyOS. La ejecución automatizada es la opción recomendada. Los detalles manuales sirven para comprender y diagnosticar el proceso.

> **Peligro:** el disco seleccionado se borra por completo. Verifica el nombre, tamaño y modelo antes de confirmar.

## Requisitos

- Live USB arrancado en modo UEFI.
- Conexión de red.
- Acceso como `root`.
- Copia externa de los datos importantes.
- Repositorio disponible en el entorno Live.

Comprueba UEFI:

```bash
test -d /sys/firmware/efi/efivars && echo UEFI || echo NO-UEFI
```

Lista los discos:

```bash
lsblk -dpno NAME,SIZE,MODEL,TYPE
```

## Ejecución recomendada

Desde la raíz del repositorio:

```bash
cd ~/cachyos-install
sudo bash base/install-base.sh
```

El script muestra los discos detectados mediante Whiptail. No exige escribir manualmente `/dev/nvme0n1`, `/dev/sda` u otra ruta.

## Navegación del asistente

Todas las pantallas de preguntas se manejan igual:

- **Aceptar** guarda la respuesta y pasa a la siguiente pregunta.
- **Atrás** vuelve a la pregunta anterior con la respuesta que ya diste marcada: si no la tocas se queda, y si eliges otra, cambia. En la primera pregunta, Atrás pide confirmar la salida.
- **Esc** pregunta si quieres salir del instalador. Si respondes que no, la misma pantalla se repite. Ni Atrás ni Esc asignan nunca un valor por defecto.
- Las contraseñas no se muestran al volver: dejar el campo vacío conserva la actual.

Al final, el resumen es un menú: puedes confirmar la instalación o ir directo a cualquier pregunta, cambiarla y volver al resumen.

## Confirmaciones de seguridad

El instalador:

1. Comprueba que el destino sea un dispositivo de bloque.
2. Advierte si contiene firmas o datos previos; en ese momento no borra nada.
3. Muestra un resumen final, desde el que puedes cambiar cualquier respuesta antes de confirmar.
4. Al elegir «CONFIRMAR E INSTALAR», pregunta una última vez si estás seguro de borrar todos los datos del disco. El botón marcado por defecto es «No», que te devuelve al resumen.

Solo después de ese «Sí» la función de particionado ejecuta `wipefs -af`, inmediatamente antes de crear la tabla GPT. Esto asegura que no queden firmas antiguas.

## Tabla de particiones

El instalador crea una tabla GPT con:

```text
Partición 1   EFI    FAT32    512 MiB
Partición 2   ROOT   Btrfs    resto del disco
```

La partición EFI se monta en:

```text
/boot/efi
```

El script reconoce nombres de partición para NVMe, MMC y discos tradicionales:

```text
/dev/nvme0n1p1
/dev/mmcblk0p1
/dev/sda1
```

Estos nombres son ejemplos. Nunca copies un dispositivo sin comprobarlo.

## LUKS2 opcional

Si se selecciona cifrado, la segunda partición se abre como:

```text
/dev/mapper/cryptroot
```

Btrfs se crea sobre ese dispositivo mapeado. La partición EFI permanece sin cifrar para permitir el arranque UEFI.

## Sistema de archivos

El instalador aplica:

```text
EFI      FAT32, etiqueta EFI
ROOT     Btrfs, etiqueta CachyOS
```

## Subvolúmenes

Se crean:

```text
@             → /
@home         → /home
@log          → /var/log
@snapshots    → /.snapshots
@pkg          → /var/cache/pacman/pkg
@swap         → /swap
@docker       → /var/lib/docker, opcional
```

`@` se establece como subvolumen Btrfs predeterminado. Esta decisión es necesaria para el modelo de rollback del proyecto.

## Opciones de montaje

Los subvolúmenes normales usan:

```text
rw,noatime,compress=zstd:1,space_cache=v2
```

`@swap` y `@docker` usan `nodatacow`:

```text
rw,noatime,nodatacow
```

La estructura se monta bajo `/mnt` y la EFI bajo `/mnt/boot/efi`.

## Swap

El instalador calcula una sugerencia según la RAM y si se habilita hibernación. Después crea el archivo con la herramienta nativa de Btrfs:

```bash
btrfs filesystem mkswapfile
```

Si se solicita hibernación, obtiene también el offset físico necesario.

## Validación

Antes de instalar paquetes:

```bash
findmnt -R /mnt
lsblk -f
sudo btrfs subvolume list /mnt
```

La salida concreta depende del disco y de si se habilitaron LUKS y Docker.

## Acceso remoto opcional

SSH no es obligatorio. Si se usa, primero comprueba el servicio en el Live USB:

```bash
systemctl status sshd
```

No asumas que está iniciado. Configura una contraseña temporal o una clave, limita el acceso a una red confiable y elimina la credencial temporal al terminar.

## Estado esperado

- Tabla GPT creada.
- Partición EFI FAT32 montada en `/mnt/boot/efi`.
- Btrfs creado directamente o dentro de LUKS2.
- Subvolúmenes creados y montados.
- `@` establecido como subvolumen predeterminado.
- Swapfile activo.
- `/mnt` listo para `pacstrap`.
