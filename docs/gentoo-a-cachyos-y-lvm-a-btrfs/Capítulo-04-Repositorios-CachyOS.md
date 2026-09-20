← [Cap. 03 — Instalación base](Capítulo-03-Instalación-base-con-pacstrap.md) · [Índice](..) · [Cap. 05 — Configuración del sistema](Capítulo-05-Configuración-del-sistema.md) →

---

En este capítulo configuramos los repositorios oficiales de CachyOS dentro del chroot. Sin este paso, el sistema resultante es Arch Linux con el kernel CachyOS, no un CachyOS completo. Los repositorios de CachyOS proveen paquetes optimizados para el nivel de instrucciones de la CPU (x86-64-v3 o x86-64-v4), además de paquetes exclusivos como `paru`, `tuigreet` y otros que no están en los repos de Arch.

> Todos los comandos de este capítulo se ejecutan **dentro del chroot**.

---

## 1. Detectar el nivel de CPU

CachyOS ofrece paquetes optimizados para tres niveles de instrucciones. El script detecta automáticamente cuál aplica:

```bash
CPU_LEVEL=""
/lib/ld-linux-x86-64.so.2 --help | grep -q "x86-64-v4 (supported" && CPU_LEVEL="v4"
[[ -z "$CPU_LEVEL" ]] && /lib/ld-linux-x86-64.so.2 --help | grep -q "x86-64-v3 (supported" && CPU_LEVEL="v3"
echo "Nivel CPU detectado: ${CPU_LEVEL:-base}"
```

Resultado esperado en hardware moderno (Intel 8ª gen o superior, AMD Zen 3 o superior):

```text
Nivel CPU detectado: v4
```

| Nivel | CPUs típicas |
|---|---|
| `v4` | Intel 8ª gen+, AMD Zen 3+ |
| `v3` | Intel 4ª–7ª gen, AMD Zen/Zen 2 |
| base | Hardware antiguo — solo repos `[cachyos]` |

---

## 2. Importar la clave GPG de CachyOS

```bash
pacman-key --recv-keys F3B607488DB35A47 --keyserver keyserver.ubuntu.com && pacman-key --lsign-key F3B607488DB35A47
```

Resultado esperado:

```text
gpg: clave F3B607488DB35A47: clave pública "CachyOS <admin@cachyos.org>" importada
  -> Firmada localmente 1 clave.
```

---

## 3. Instalar keyring y mirrorlist

El script descarga dinámicamente los paquetes más recientes del mirror de CachyOS — sin URLs hardcodeadas que queden obsoletas:

```bash
MIRROR="https://mirror.cachyos.org/repo/x86_64/cachyos"
pkg_latest() { curl -s "${MIRROR}/" | grep -oE "${1}-[0-9][^\"' ]+\.pkg\.tar\.zst" | sort -V | tail -1; }
PKGS=("${MIRROR}/$(pkg_latest cachyos-keyring)" "${MIRROR}/$(pkg_latest cachyos-mirrorlist)")
[[ -n "$CPU_LEVEL" ]] && PKGS+=("${MIRROR}/$(pkg_latest "cachyos-${CPU_LEVEL}-mirrorlist")")
pacman -U --noconfirm "${PKGS[@]}"
```

Resultado esperado:

```text
(1/3) instalando cachyos-keyring
(2/3) instalando cachyos-mirrorlist
(3/3) instalando cachyos-v4-mirrorlist
```

---

## 4. Agregar los repositorios a pacman.conf

El siguiente bloque es **idempotente**: verifica si los repos ya están presentes antes de modificar el archivo.

```bash
if ! grep -q "^\[cachyos\]" /etc/pacman.conf; then
    if [[ "$CPU_LEVEL" == "v4" ]]; then
        REPOS="[cachyos-v4]\nInclude = /etc/pacman.d/cachyos-v4-mirrorlist\n\n[cachyos-extra-v4]\nInclude = /etc/pacman.d/cachyos-v4-mirrorlist\n\n[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist"
    elif [[ "$CPU_LEVEL" == "v3" ]]; then
        REPOS="[cachyos-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos-extra-v3]\nInclude = /etc/pacman.d/cachyos-v3-mirrorlist\n\n[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist"
    else
        REPOS="[cachyos]\nInclude = /etc/pacman.d/cachyos-mirrorlist"
    fi
    sed -i "/^\[core\]/i ${REPOS}\n" /etc/pacman.conf
    echo "Repos CachyOS agregados"
else
    echo "Repos CachyOS ya presentes — sin cambios"
fi
```

---

## 5. Verificar la configuración

```bash
grep -E "^\[cachyos" /etc/pacman.conf
```

Resultado esperado para v4:

```text
[cachyos-v4]
[cachyos-extra-v4]
[cachyos]
```

```bash
pacman -Syu --noconfirm
```

La sincronización debe mostrar los nuevos repos descargando sus bases de datos:

```text
 cachyos-v4      117,1 KiB
 cachyos-extra-v4  4,2 MiB
 cachyos           520,4 KiB
 core está actualizado
 extra está actualizado
```

---

## Estado esperado al final del capítulo

Al terminar este capítulo:

- La clave GPG de CachyOS está importada y firmada localmente.
- Los paquetes `cachyos-keyring` y `cachyos-mirrorlist` (y la variante v3/v4 según la CPU) están instalados.
- `/etc/pacman.conf` contiene las secciones `[cachyos-v4]`, `[cachyos-extra-v4]` y `[cachyos]` (o sus equivalentes v3/base) antes de `[core]`.
- Las bases de datos de los repositorios CachyOS están sincronizadas.

El siguiente capítulo configura el sistema: locale, hostname, zona horaria, usuario y sudo.

---

← [Cap. 03 — Instalación base](Capítulo-03-Instalación-base-con-pacstrap.md) · [Índice](..) · [Cap. 05 — Configuración del sistema](Capítulo-05-Configuración-del-sistema.md) →
