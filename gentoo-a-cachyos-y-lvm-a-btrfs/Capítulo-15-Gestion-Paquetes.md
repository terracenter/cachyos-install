← [Cap. 14 — Uso de Hyprland](Capítulo-14-Uso-Hyprland.md) · [Índice](..) · [Cap. 16 — Acceso remoto](Capítulo-16-Acceso-Remoto.md) →

---

## Introducción

CachyOS es Arch-based. El gestor de paquetes nativo es **pacman**, complementado con **paru** como AUR helper. CachyOS añade sus propios repositorios con paquetes optimizados para arquitecturas modernas (x86-64-v3, x86-64-v4).

| Herramienta | Repositorios | Requiere sudo |
|---|---|---|
| `pacman` | Arch + CachyOS | Sí |
| `paru` | Arch + CachyOS + AUR | No |

> `paru` llama a `sudo` internamente cuando es necesario. Para operaciones del sistema usa `paru`; reserva `pacman` para scripts que requieran control explícito del sudo.

---

## pacman — operaciones básicas

### Instalar paquetes

```bash
sudo pacman -S nombre-paquete
sudo pacman -S --needed nombre-paquete   # no reinstala si ya está instalado
```

### Actualizar el sistema

```bash
sudo pacman -Syu
```

### Eliminar paquetes

```bash
sudo pacman -R nombre-paquete            # elimina el paquete
sudo pacman -Rs nombre-paquete           # elimina con dependencias huérfanas
sudo pacman -Rns nombre-paquete          # elimina con dependencias y archivos de configuración
```

### Buscar paquetes

```bash
pacman -Ss término                       # buscar en repositorios
pacman -Qs término                       # buscar en instalados
```

### Información de paquetes

```bash
pacman -Si nombre-paquete                # info del repositorio
pacman -Qi nombre-paquete                # info del instalado
pacman -Ql nombre-paquete                # archivos instalados por el paquete
pacman -Q                                # listar todos los instalados
pacman -Qe                               # listar solo los instalados explícitamente
```

---

## paru — AUR helper

`paru` tiene sintaxis idéntica a `pacman`. La diferencia es que accede también al AUR (Arch User Repository) y no requiere `sudo` — lo gestiona internamente.

### Instalar (repo oficial o AUR)

```bash
paru -S nombre-paquete
paru -S --needed nombre-paquete
```

### Actualizar sistema completo (repos + AUR)

```bash
paru -Syu
```

### Buscar en AUR

```bash
paru -Ss término
paru -Sa término                         # buscar solo en AUR
```

### Operaciones solo en AUR

```bash
paru --aur -Syu                          # actualizar solo paquetes AUR
```

> Los paquetes del AUR se compilan localmente. `paru` muestra el PKGBUILD para revisión antes de instalar — responder `N` para cancelar si algo parece sospechoso.

---

## Repositorios CachyOS

CachyOS agrega sus propios repos en `/etc/pacman.conf`. Incluyen paquetes recompilados con optimizaciones para CPUs modernos y el kernel CachyOS.

Ver repositorios activos:

```bash
pacman-conf --repo-list
```

Los repos `cachyos`, `cachyos-core`, `cachyos-extra` y `cachyos-multilib` contienen versiones optimizadas de paquetes comunes (mesa, ffmpeg, gcc, etc.).

---

## Mantenimiento

### Actualización completa del sistema

```bash
paru -Syu
```

Actualiza repos oficiales, CachyOS y AUR en un solo comando.

### Limpiar caché de paquetes

pacman guarda todos los paquetes descargados en `/var/cache/pacman/pkg/`. Limpiar periódicamente:

```bash
sudo pacman -Sc     # elimina versiones antiguas, conserva la instalada
sudo pacman -Scc    # elimina toda la caché (libera más espacio)
```

### Eliminar paquetes huérfanos

Paquetes instalados como dependencia que ya no son necesarios:

```bash
pacman -Qtdq                              # listar huérfanos
sudo pacman -Rns $(pacman -Qtdq)         # eliminarlos (si hay alguno)
```

### Actualizar mirrors

CachyOS incluye `cachyos-rate-mirrors` para ordenar los mirrors por velocidad. Se ejecuta automáticamente vía timer, pero se puede lanzar manualmente:

```bash
rate-mirrors --protocol https cachyos | sudo tee /etc/pacman.d/cachyos-mirrorlist
```

Verificar cuándo se ejecutó el timer por última vez:

```bash
systemctl status cachyos-rate-mirrors.timer
```

### Verificar integridad de paquetes instalados

```bash
sudo pacman -Qk 2>&1 | grep -v "0 advertencias"
```

---

## Snapper — instantáneas automáticas

CachyOS incluye **snapper** integrado con pacman. Cada instalación o actualización de paquetes genera automáticamente dos snapshots del sistema de archivos (pre y post):

```
==> root: 82    ← snapshot pre-instalación
==> root: 83    ← snapshot post-instalación
```

Listar snapshots:

```bash
sudo snapper -c root list
```

Comparar cambios entre snapshots:

```bash
sudo snapper -c root diff 82..83
```

Restaurar a un snapshot anterior (desde live USB si el sistema no arranca):

```bash
sudo snapper -c root undochange 83..82
```

> Los snapshots requieren que la partición raíz esté en **Btrfs**. Si el sistema usa ext4, snapper no genera snapshots.

---

## Referencia rápida

```
paru -Syu               → actualizar todo
paru -S paquete         → instalar
paru -Ss término        → buscar
pacman -Qi paquete      → info del instalado
pacman -Rns paquete     → desinstalar limpio
sudo pacman -Sc         → limpiar caché
pacman -Qtdq            → listar huérfanos
```

---

← [Cap. 14 — Uso de Hyprland](Capítulo-14-Uso-Hyprland.md) · [Índice](..) · [Cap. 16 — Acceso remoto](Capítulo-16-Acceso-Remoto.md) →
