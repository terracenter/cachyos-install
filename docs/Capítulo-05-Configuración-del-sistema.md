# Capítulo 05: Configuración del sistema

[← Cap. 04: Repositorios CachyOS](Capítulo-04-Repositorios-CachyOS.md) · [Índice](./_index.md) · [Cap. 06: Snapper →](Capítulo-06-Configuración-de-Snapper.md)

## Objetivo

`base/install-base.sh` configura el sistema instalado antes del primer arranque. Este capítulo describe el comportamiento actual del instalador y las comprobaciones recomendadas.

La mayor parte de la configuración se escribe en `/mnt` y las acciones que requieren el entorno instalado se ejecutan mediante `arch-chroot`.

## Zona horaria

El instalador permite elegir una zona de `/usr/share/zoneinfo` y crea:

```text
/etc/localtime → /usr/share/zoneinfo/<zona>
```

Dentro del chroot ejecuta:

```bash
hwclock --systohc
```

Después del primer arranque verifica:

```bash
timedatectl
```

## Locale

El usuario selecciona un locale, por ejemplo:

```text
es_VE.UTF-8
en_US.UTF-8
```

El instalador lo habilita en `/etc/locale.gen`, genera los locales y crea:

```text
/etc/locale.conf
```

Comprueba:

```bash
localectl status
cat /etc/locale.conf
```

## Teclado de consola y teclado gráfico

El proyecto distingue dos configuraciones:

1. `KEYMAP`, usado en la consola virtual y guardado en `/etc/vconsole.conf`.
2. `XKB_LAYOUT` y `XKB_VARIANT`, usados por el entorno gráfico.

Para un teclado físico US con teclas muertas:

```text
KEYMAP=us
XKB layout=us
XKB variant=intl
```

En Hyprland, `'` seguido de `a` produce `á` y `~` seguido de `n` produce `ñ`.

El instalador genera también:

```text
/etc/X11/xorg.conf.d/00-keyboard.conf
```

La configuración específica de Hyprland se vuelve a generar desde su módulo de teclado y mouse.

## Hostname y resolución local

El nombre elegido se guarda en:

```text
/etc/hostname
```

El instalador genera `/etc/hosts` con:

```text
127.0.0.1   localhost
::1         localhost
127.0.1.1   equipo.localdomain equipo
```

`equipo` representa el hostname seleccionado por el usuario.

Comprueba después del arranque:

```bash
hostnamectl
getent hosts "$(hostname)"
```

## Usuario y privilegios

El instalador crea el usuario con Bash y lo añade a:

```text
wheel audio video storage optical
```

La administración mediante `sudo` se concede al grupo estándar de Arch Linux:

```text
wheel
```

La regla habilitada es:

```text
%wheel ALL=(ALL:ALL) ALL
```

No se crea un grupo adicional llamado `sudo`.

Los grupos `audio` y `video` se conservan por compatibilidad con herramientas y dispositivos, pero no deben describirse como un requisito universal para que Hyprland pueda iniciar.

Comprueba:

```bash
id
sudo -v
```

## Cuenta root

El instalador bloquea la contraseña de root:

```bash
passwd -l root
```

La administración normal se realiza desde el usuario perteneciente a `wheel` mediante `sudo`.

Antes de bloquear root, asegúrate de que el usuario fue creado, recibió contraseña y conserva acceso administrativo.

## Shell interactivo

El usuario puede elegir:

- Bash sin modificaciones.
- Bash mejorado.
- Zsh con complementos.

La instalación base no exige Zsh. El usuario se crea inicialmente con `/bin/bash`; la personalización elegida se aplica después.

## Red y acceso remoto

El instalador habilita:

```text
NetworkManager.service
sshd.service
```

Comprueba después del primer arranque:

```bash
systemctl is-enabled NetworkManager
systemctl is-enabled sshd
systemctl status NetworkManager
```

Si no necesitas acceso SSH, puedes deshabilitarlo después de confirmar que no dependes de él:

```bash
sudo systemctl disable --now sshd
```

## Generación en chroot

Dentro del chroot se ejecutan, entre otras tareas:

```bash
locale-gen
hwclock --systohc
mkinitcpio -P
grub-mkconfig -o /boot/grub/grub.cfg
```

No repitas estos comandos sin comprender qué archivos regeneran.

## Validación final

Después del primer arranque:

```bash
timedatectl
localectl status
hostnamectl
id
sudo -v
systemctl --failed
systemctl is-enabled NetworkManager
```

Comprueba los archivos principales:

```bash
cat /etc/locale.conf
cat /etc/vconsole.conf
cat /etc/hostname
cat /etc/hosts
```

## Estado esperado

- Zona horaria y reloj de hardware configurados.
- Locale generado.
- Teclado de consola y XKB definidos por separado.
- Hostname y resolución local configurados.
- Usuario creado con contraseña y acceso por `wheel`.
- Cuenta root bloqueada.
- NetworkManager habilitado.
- SSH habilitado por el instalador y disponible para revisión posterior.

## Referencias

- ArchWiki, usuarios y grupos: <https://wiki.archlinux.org/title/Users_and_groups>
- ArchWiki, configuración regional: <https://wiki.archlinux.org/title/Locale>
- ArchWiki, NetworkManager: <https://wiki.archlinux.org/title/NetworkManager>
