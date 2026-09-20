← [Cap. 04 — Repositorios CachyOS](Capítulo-04-Repositorios-CachyOS.md) · [Índice](..) · [Cap. 06 — Configuración de Snapper](Capítulo-06-Configuración-de-Snapper.md) →

---

En este capítulo configuramos el sistema base recién instalado: zona horaria, idioma, teclado, hostname, contraseña de root, usuario personal y sudo.

> Todos los comandos de este capítulo se ejecutan **dentro del chroot** (`arch-chroot /mnt`). Si cerraste la sesión, entra nuevamente con `arch-chroot /mnt` desde el Live USB como root.

---

## 1. Zona horaria

Busca tu zona horaria si no la sabes:

```bash
timedatectl list-timezones | grep -i america
```

Configura la zona horaria. Reemplaza `America/Caracas` por la tuya:

```bash
ln -sf /usr/share/zoneinfo/America/Caracas /etc/localtime
```

Sincroniza el reloj de hardware con el sistema:

```bash
hwclock --systohc
```

Verifica:

```bash
date
```

La salida debe mostrar la fecha y hora correcta con tu zona horaria.

---

## 2. Idioma del sistema (locale)

Abre el archivo de configuración de locales:

```bash
vim /etc/locale.gen
```

Busca y descomenta las líneas correspondientes a tu idioma. Elimina el `#` del inicio de cada línea que necesites. Ejemplos comunes:

```text
es_VE.UTF-8 UTF-8
es_ES.UTF-8 UTF-8
en_US.UTF-8 UTF-8
```

Guarda el archivo y genera los locales:

```bash
locale-gen
```

Resultado esperado:

```text
Generating locales...
  es_VE.UTF-8... done
  en_US.UTF-8... done
Generation complete.
```

Crea el archivo de configuración del locale del sistema. Reemplaza `es_VE.UTF-8` por el locale que elegiste:

```bash
echo "LANG=es_VE.UTF-8" > /etc/locale.conf
```

Verifica:

```bash
cat /etc/locale.conf
```

---

## 3. Distribución del teclado en consola

Para ver todos los keymaps disponibles en el sistema:

```bash
localectl list-keymaps
```

Configura el keymap según tu teclado físico:

| Teclado | KEYMAP |
|---|---|
| Español (España/Latino) | `es` |
| Latinoamericano | `la-latin1` |
| Inglés US estándar | `us` |
| Inglés US con acentos (dead keys) | `us-acentos` |

El keymap `us-acentos` es la opción para quienes tienen teclado físico en inglés pero necesitan escribir caracteres acentuados. Usa **teclas muertas**: primero el acento, luego la vocal (`'` + `a` → `á`, `~` + `n` → `ñ`).

```bash
echo "KEYMAP=us-acentos" > /etc/vconsole.conf
```

Puedes probar el keymap sin guardar antes de confirmarlo:

```bash
loadkeys us-acentos
```

Verifica:

```bash
cat /etc/vconsole.conf
```

---

## 4. Nombre del equipo (hostname)

Define el nombre que tendrá tu máquina en la red. Reemplaza `cachyos-pc` por el nombre que prefieras:

```bash
echo "cachyos-pc" > /etc/hostname
```

Verifica:

```bash
cat /etc/hostname
```

---

## 5. Configurar /etc/hosts

El archivo `/etc/hosts` es necesario para la resolución local de nombres. Ábrelo:

```bash
vim /etc/hosts
```

Agrega las siguientes líneas al final. Reemplaza `cachyos-pc` por el hostname que definiste en el paso anterior:

```text
127.0.0.1   localhost
::1         localhost
127.0.1.1   cachyos-pc.localdomain  cachyos-pc
```

Verifica:

```bash
cat /etc/hosts
```

---

## 6. Contraseña de root (opcional)

Si planeas administrar el sistema exclusivamente con `sudo` desde tu usuario personal, puedes omitir este paso. Si prefieres tener acceso directo a `root`, establece la contraseña ahora:

```bash
passwd
```

Ingresa la contraseña dos veces cuando se solicite.

---

## 7. Crear usuario personal

### 7.1 Instalar zsh

Antes de crear el usuario, instala `zsh`:

```bash
pacman -S zsh
```

Verifica que quedó instalado y nota la ruta del ejecutable:

```bash
which zsh
```

Resultado esperado:

```text
/usr/bin/zsh
```

### 7.2 Crear el usuario

El grupo `sudo` no existe por defecto en CachyOS/Arch. Créalo primero:

```bash
groupadd sudo
```

Crea tu usuario de trabajo con `zsh` como shell por defecto. Reemplaza `usuario` por tu nombre de usuario:

```bash
useradd -m -G sudo,input,video -s /usr/bin/zsh usuario
```

| Opción | Descripción |
|---|---|
| `-m` | Crea el directorio home (`/home/usuario`) |
| `-G sudo` | Permite usar `sudo` |
| `-G input` | Acceso a dispositivos de entrada (`/dev/input/*`) — requerido por Hyprland para teclado y touchpad |
| `-G video` | Acceso a dispositivos DRM/GPU (`/dev/dri/*`) — requerido por Hyprland para abrir el compositor |
| `-s /usr/bin/zsh` | Establece zsh como shell por defecto |

Asigna contraseña al nuevo usuario:

```bash
passwd usuario
```

Ingresa la contraseña dos veces cuando se solicite.


---

## 8. Configurar sudo

Abre el archivo de configuración de sudo con el editor seguro `visudo`. Nunca edites `/etc/sudoers` directamente:

```bash
EDITOR=vim visudo
```

El grupo `sudo` no tiene entrada en el archivo por defecto — hay que agregarla manualmente. Al final del archivo, añade esta línea:

```text
%sudo ALL=(ALL:ALL) ALL
```

Guarda y cierra el archivo. `visudo` valida la sintaxis antes de guardar — si hay un error, te avisará.

Verifica que la regla quedó registrada:

```bash
grep sudo /etc/sudoers
```

Resultado esperado:

```text
%sudo ALL=(ALL:ALL) ALL
```

---

## 9. Habilitar NetworkManager

Habilita el servicio de red para que arranque automáticamente en cada inicio del sistema:

```bash
systemctl enable NetworkManager
```

Resultado esperado:

```text
Created symlink /etc/systemd/system/multi-user.target.wants/NetworkManager.service → /usr/lib/systemd/system/NetworkManager.service.
```

---

## 10. Verificación final

Confirma la zona horaria configurada:

```bash
ls -la /etc/localtime
```

Resultado esperado (el enlace apunta a tu zona):

```text
lrwxrwxrwx 1 root root 38 ...  /etc/localtime -> /usr/share/zoneinfo/America/Caracas
```

Confirma el locale:

```bash
cat /etc/locale.conf
```

Confirma el hostname:

```bash
cat /etc/hostname
```

Confirma que el usuario fue creado con los grupos correctos:

```bash
id usuario
```

Resultado esperado:

```text
uid=1000(usuario) gid=1000(usuario) groups=1000(usuario),998(sudo),986(input),985(video)
```

Confirma que NetworkManager está habilitado:

```bash
systemctl is-enabled NetworkManager
```

Resultado esperado:

```text
enabled
```

---

## Estado esperado al final del capítulo

Al terminar este capítulo:

- La zona horaria y el reloj de hardware están sincronizados.
- El locale y la distribución de teclado están configurados.
- El hostname y `/etc/hosts` están definidos.
- El usuario `root` tiene contraseña.
- Existe un usuario personal con contraseña y perteneciente al grupo `sudo`.
- `sudo` está configurado para el grupo `sudo`.
- `NetworkManager` está habilitado para arrancar con el sistema.

El siguiente capítulo configura snapper y sus hooks automáticos de pacman.

---

← [Cap. 04 — Repositorios CachyOS](Capítulo-04-Repositorios-CachyOS.md) · [Índice](..) · [Cap. 06 — Configuración de Snapper](Capítulo-06-Configuración-de-Snapper.md) →
