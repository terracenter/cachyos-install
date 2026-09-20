[Índice](..) · [Cap. 02 — Particionado y montaje](Capítulo-02-Particionado-y-montaje-desde-el-Live-USB.md) →

---

## Introducción: El fin de la era de compilación infinita

Como usuario de Gentoo de larga data, la estabilidad de LVM y la velocidad de XFS han sido mis pilares. Sin embargo, hay una realidad ineludible: **la vida es corta y los tiempos de compilación son largos.** Compilar el kernel o paquetes pesados en una laptop consume un tiempo precioso que hoy prefiero dedicar a producir.

Viviendo en Venezuela, donde los cortes eléctricos son una constante agresiva, la capacidad de **auto-reparación** y los **snapshots atómicos** de BTRFS ofrecen una capa de seguridad que el esquema tradicional no puede igualar. Una actualización que mata el sistema a mitad, un corte de luz en el momento equivocado — con LVM y XFS eso es una tarde de recuperación. Con BTRFS y snapper, es un rollback de treinta segundos.

**CachyOS** es la respuesta: binarios optimizados con un kernel agresivo (scheduler BORE), instalación en minutos, y sin renunciar al control absoluto de la consola. Este handbook documenta la migración completa.

---

## 1. El cambio de paradigma: De LVM a BTRFS

En mi configuración anterior con LVM, el espacio estaba atrapado en muros rígidos. Si `/var` se llenaba, el sistema sufría hasta que yo expandiera manualmente el volumen lógico con `lvextend` y redimensionara el sistema de archivos con `resize2fs`. Un proceso tedioso, con riesgo de error.

**Con BTRFS esos muros desaparecen:**

| LVM + XFS | BTRFS |
|---|---|
| Espacio asignado fijo por volumen lógico | Pool compartido — todos los subvolúmenes ven el total disponible |
| `lvextend` + `resize2fs` para expandir | El espacio fluye solo hacia donde se necesita |
| Sin snapshots nativos | Snapshots atómicos, instantáneos, sin costo inicial |
| Rollback = restaurar backup | Rollback = 4 comandos, 30 segundos |

---

## 2. ¿Qué es un snapshot en BTRFS?

Un snapshot no es una copia completa de los datos. Es un **puntero** que congela el estado de un subvolumen en un momento exacto.

Imagina una pizarra con dibujos. Un snapshot es como tomar una fotografía: la foto no ocupa el mismo espacio que la pizarra, solo registra qué había dibujado. Cuando modificas la pizarra original, la foto sigue mostrando el estado anterior.

**Técnicamente**: BTRFS usa Copy-on-Write (CoW). Cuando haces un snapshot:
- Se crea un nuevo subvolumen que apunta a los mismos bloques de datos que el original.
- Si modificas el original, BTRFS copia SOLO los bloques que cambias.
- El snapshot sigue apuntando a los bloques viejos.

**Resultado**: Hacer un snapshot es instantáneo (milisegundos) y casi no ocupa espacio inicialmente.

---

## 3. ¿Dónde viven los snapshots?

Los snapshots son subvolúmenes normales. Por convención se guardan dentro de `/.snapshots`:

```
/.snapshots/
├── 1/
│   ├── info.xml       (metadatos: fecha, descripción)
│   └── snapshot/      (el subvolumen snapshot real)
├── 2/
│   └── ...
```

La herramienta `snapper` gestiona esta estructura automáticamente.

---

## 4. ¿Qué significa el símbolo `@`?

Al configurar BTRFS notarás que los subvolúmenes se nombran `@`, `@home`, `@log`, etc. No es una regla técnica del sistema de archivos — es una **convención de la comunidad**.

El `@` permite identificar visualmente qué es un subvolumen y qué es un directorio común. Herramientas como `grub-btrfs` y `snapper` lo buscan por defecto para automatizar snapshots y entradas en el menú de GRUB.

---

## 5. La regla de oro: Los snapshots NO son recursivos entre montajes

Este es el punto que más confunde a los usuarios nuevos.

**El error mental clásico:**
- Tienes `@` montado en `/`
- Tienes `@home` montado en `/home`
- Piensas: "Si hago snapshot de `@`, tendré copia de TODO, incluyendo `/home`"

**La realidad:** Cuando montas `@home` sobre `/home`, le dices al sistema que `/home` es un sistema de archivos independiente. El subvolumen `@` NO ve lo que hay dentro de `@home`.

```
Subvolumen @              Subvolumen @home
├── bin/                  ├── usuario1/
├── etc/                  │   ├── Documentos/
├── usr/                  │   └── Descargas/
└── home/  ← VACÍO        └── usuario2/
   (porque @home se monta encima)
```

**Consecuencia práctica:**
- Snapshot de `@` = respaldo del sistema operativo (sin datos de usuario)
- Snapshot de `@home` = respaldo de tus documentos
- Para un respaldo completo necesitas snapshots de ambos

---

## 6. ¿Qué significa arrancar desde un snapshot?

Cuando arrancas normalmente, GRUB pasa al kernel:

```
root=/dev/nvme0n1p2 rootflags=subvol=@
```

Si quieres arrancar desde un snapshot, GRUB pasa:

```
root=/dev/nvme0n1p2 rootflags=subvol=@/.snapshots/1/snapshot
```

El kernel monta el snapshot como si fuera el sistema raíz. Verás todos tus archivos tal como estaban en el momento del snapshot. El acceso es en **modo solo lectura** por seguridad.

---

## 7. Rollback: convertir un snapshot en el sistema activo

Arrancar desde un snapshot es temporal. Para que el snapshot se convierta en tu sistema permanente:

1. Renombrar el subvolumen `@` actual como `@.broken`
2. Crear un nuevo `@` a partir del snapshot deseado
3. Reiniciar

El Capítulo 11 documenta este procedimiento en detalle.

---

## 8. ¿Por qué separar ciertos directorios en subvolúmenes independientes?

| Directorio | ¿Separar? | Motivo |
|---|---|---|
| `/home` | **Sí** | No perder documentos al restaurar el sistema |
| `/var/log` | **Sí** | Los logs sobreviven al rollback para diagnosticar qué falló |
| `/var/cache` | **Sí** | La caché de paquetes no necesita respaldo — ahorra espacio |
| `/var/lib/docker` | **Sí** | Las imágenes Docker son gigabytes, no conviene snapshotearlas |
| `/var/lib/containerd` | **Sí** | Mismo criterio que Docker |
| `/boot` | **Dentro de `@`** | Los kernels se incluyen en snapshots — rollback consistente |

---

## 9. El dilema de `/boot`: consistencia vs compatibilidad

**Escenario A — EFI montado en `/boot` (FAT32 fuera de BTRFS):**
- Los kernels NO están en snapshots
- Restauras el sistema pero el kernel sigue siendo el nuevo
- Riesgo: incompatibilidad kernel ↔ módulos o initramfs

**Escenario B — EFI en `/efi`, `/boot` dentro de BTRFS (este handbook):**
- Los kernels SÍ están en snapshots
- Restauras sistema + kernel exacto que funcionaba
- Rollbacks consistentes y seguros

Este handbook usa el Escenario B. Es la configuración que usan distribuciones empresariales como openSUSE para garantizar rollbacks fiables.

---

## 10. Estructura final del sistema

```
Partición EFI (FAT32)          Partición BTRFS (pool)
/dev/nvme0n1p1                 /dev/nvme0n1p2
│                              │
└── /efi/                      ├── @              → montado en /
    └── EFI/CachyOS/           ├── @home          → montado en /home
        └── grubx64.efi        ├── @log           → montado en /var/log
                               ├── @snapshots     → montado en /.snapshots
                               ├── @pkg           → montado en /var/cache/pacman/pkg
                               ├── @swap          → montado en /swap
                               ├── @docker        → montado en /var/lib/docker
                               └── snapshots
                                   └── 1/snapshot/
```

---

## 11. Lo que aprenderás en los siguientes capítulos

| Capítulo | Contenido |
|---|---|
| 2 | Particionado y montaje desde el Live USB |
| 3 | Instalación base con pacstrap |
| 4 | Repositorios CachyOS |
| 5 | Configuración del sistema: locale, hostname, usuarios |
| 6 | Configuración de Snapper y hooks automáticos de pacman |
| 7 | Configuración de GRUB con soporte para snapshots |
| 8 | Configuración de mkinitcpio |
| 9 | Verificación de snapshots |
| 10 | Primer arranque |
| 11 | Rollback desde GRUB o chroot |
| 12 | Instalación del entorno gráfico Hyprland (estilo Omarchy) |
| 13 | Configuración de Waybar |
| 14 | Uso de Hyprland: combinaciones de teclas |
| 15 | Gestión de paquetes |
| 16 | Acceso remoto |
| 17 | Herramientas CLI modernas |
| 18 | Gaming: Steam, GameMode, MangoHud, Proton-GE |

---

[Índice](..) · [Cap. 02 — Particionado y montaje](Capítulo-02-Particionado-y-montaje-desde-el-Live-USB.md) →
