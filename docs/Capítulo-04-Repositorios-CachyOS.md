# Capítulo 04: Repositorios de CachyOS

[← Cap. 03: Instalación base](Capítulo-03-Instalación-base-con-pacstrap.md) · [Índice](./_index.md) · [Cap. 05: Configuración del sistema →](Capítulo-05-Configuración-del-sistema.md)

## Objetivo

Este capítulo explica cómo `base/install-base.sh` conserva la configuración oficial de repositorios de CachyOS en el sistema nuevo.

CachyOS ofrece paquetes optimizados para distintos niveles de CPU. La selección concreta debe provenir de una configuración oficial y vigente, no de asociaciones manuales entre generaciones comerciales y niveles x86-64.

## Fuente de verdad

La instalación se ejecuta desde un Live USB de CachyOS que ya dispone de:

- Keyring de CachyOS.
- Mirrorlists oficiales.
- Secciones de repositorio configuradas en `/etc/pacman.conf`.

Por ello, el instalador no reconstruye los repositorios analizando páginas HTML, importando una clave fija desde un servidor externo ni manteniendo una tabla manual de procesadores.

## Paquetes instalados

Durante `pacstrap` se incluyen:

```text
cachyos-keyring
cachyos-mirrorlist
```

El keyring permite verificar firmas de paquetes. La mirrorlist define servidores de descarga.

## Configuración copiada desde el Live USB

Después de `pacstrap`, el instalador copia:

```text
/etc/pacman.conf
```

hacia:

```text
/mnt/etc/pacman.conf
```

También copia todas las mirrorlists disponibles cuyo nombre coincida con:

```text
/etc/pacman.d/cachyos*-mirrorlist
```

El patrón permite incorporar automáticamente las variantes presentes en la imagen Live, por ejemplo:

```text
cachyos-mirrorlist
cachyos-v3-mirrorlist
cachyos-v4-mirrorlist
cachyos-znver4-mirrorlist
```

La lista exacta puede cambiar con el tiempo. El instalador copia únicamente los archivos que realmente existen en el Live USB.

## Selección de mirrors

Antes de instalar el sistema base, el script intenta ejecutar:

```bash
cachyos-rate-mirrors
```

Si la herramienta no está disponible, intenta instalarla en el entorno Live. Si no puede usarse, conserva la lista de mirrors existente y muestra una advertencia.

La disponibilidad y sincronización de los mirrors cambia con el tiempo. Evita introducir URLs individuales en el instalador o en la documentación.

## Nivel de optimización de CPU

No asocies automáticamente una generación de Intel o AMD con `x86-64-v3`, `x86-64-v4` o `znver4`. La compatibilidad depende de las instrucciones que soporte el procesador.

Como diagnóstico puede consultarse:

```bash
/lib/ld-linux-x86-64.so.2 --help |
  grep -A3 'Subdirectories of glibc-hwcaps'
```

Sin embargo, el instalador debe conservar la selección oficial ya configurada en el Live USB de CachyOS.

## Verificación dentro del sistema instalado

Comprueba los paquetes:

```bash
arch-chroot /mnt pacman -Q \
  cachyos-keyring \
  cachyos-mirrorlist
```

Revisa las secciones activas:

```bash
grep -nE '^\[cachyos' /mnt/etc/pacman.conf
```

Lista las mirrorlists copiadas:

```bash
find /mnt/etc/pacman.d \
  -maxdepth 1 \
  -type f \
  -name 'cachyos*-mirrorlist' \
  -print
```

Sincroniza las bases dentro del chroot:

```bash
arch-chroot /mnt pacman -Syy
```

`-Syy` se utiliza aquí para inicializar o forzar la sincronización durante la instalación. En el sistema ya instalado, las actualizaciones normales deben ser completas:

```bash
sudo pacman -Syu
```

## Prácticas que deben evitarse

No uses como procedimiento principal:

- Analizar HTML para adivinar el paquete más reciente.
- Importar una huella GPG fija desde un keyserver externo.
- Descargar manualmente paquetes del keyring sin verificar su procedencia.
- Construir repositorios con una tabla generacional de CPU escrita a mano.
- Ejecutar `pacman -Sy` como actualización parcial habitual.
- Mantener una lista rígida de mirrorlists que pueda quedar obsoleta.

## Estado esperado

Al terminar:

- `cachyos-keyring` y `cachyos-mirrorlist` están instalados.
- `/mnt/etc/pacman.conf` procede del Live USB oficial.
- Las mirrorlists disponibles fueron copiadas a `/mnt/etc/pacman.d/`.
- Pacman puede sincronizar las bases de datos dentro del chroot.
- El sistema conserva la variante de repositorios seleccionada por CachyOS.

## Referencias

- CachyOS: <https://cachyos.org/>
- Mirrors de CachyOS: <https://dashboard.cachyos.org/mirrors>
- Repositorio de mirrorlists: <https://github.com/CachyOS/CachyOS-PKGBUILDS/tree/master/cachyos-mirrorlist>
