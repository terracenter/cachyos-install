← [Cap. 10 — Primer arranque](Capítulo-10-Primer-arranque.md) · [Índice](..) · [Cap. 12 — Instalación Hyprland](Capítulo-12-Instalacion-Hyprland.md) →

---

Este capítulo cubre el procedimiento completo para revertir el sistema a un estado anterior usando los snapshots creados por snapper.

---

## Conceptos previos: tres herramientas distintas

| Herramienta | Para qué sirve |
|---|---|
| `snapper list` | Listar snapshots e identificar el número objetivo |
| Menú GRUB → CachyOS Snapshots | Arrancar temporalmente en **modo solo lectura** — solo para verificar |
| Procedimiento de rollback (Escenarios A y B) | Hacer el rollback **permanente** — reemplaza `@` con el snapshot |

**Arrancar desde el menú de GRUB no hace el rollback permanente.** El snapshot se monta en modo solo lectura. Al reiniciar, el sistema vuelve al `@` de siempre.

El árbol de decisión cuando algo falla:

```
Sistema roto después de un cambio
           │
           ▼
¿Arranca el sistema (aunque sea sin entorno gráfico)?
           │
      SÍ ──┼──► Escenario A: rollback desde el sistema vivo
           │
      NO ──┼──► Escenario B: rollback desde el Live USB
```

---

## 1. Identificar el snapshot objetivo

Tanto en el Escenario A como en el B, el primer paso es saber a cuál snapshot quieres volver.

Si el sistema arranca (aunque esté roto):

```bash
snapper -c root list
```

Ejemplo de salida:

```text
 # │ Tipo   │ Pre número │ Fecha                    │ Usuario │ Limpieza │ Descripción
───┼────────┼────────────┼──────────────────────────┼─────────┼──────────┼──────────────────────────────
 0 │ single │            │                          │ root    │          │ current
 1 │ single │            │ sáb 16 may 2026 19:34:50 │ root    │          │ sistema base limpio post-instalacion
 2 │ pre    │            │ sáb 16 may 2026 19:55:18 │ root    │ number   │ pacman -Syyyu
 3 │ post   │          2 │ sáb 16 may 2026 19:55:24 │ root    │ number   │ mkinitcpio zstd
13 │ single │            │ dom 17 may 2026 10:00:00 │ root    │          │ pre-instalacion-hyprland
```

Anota el número `#` del snapshot deseado. El `0` es el estado actual — no se puede usar para rollback.

Si el sistema no arranca, identificas el snapshot en el Escenario B (sección 4.3).

---

## 2. Verificar el snapshot desde el menú de GRUB (opcional)

Si quieres confirmar que el snapshot objetivo es el correcto antes de hacer el rollback:

1. Reinicia el sistema.
2. En el menú de GRUB selecciona **CachyOS Snapshots**.
3. Busca la entrada que corresponde al snapshot por fecha y descripción.
4. Arranca desde ese snapshot.

El sistema inicia en modo **solo lectura**. Verifica que el estado es el que esperas: paquetes instalados, configuraciones, etc.

Cuando termines de verificar, reinicia. El sistema vuelve al `@` actual. Ahora ya sabes el número del snapshot al que quieres volver y procedes con el Escenario A o B.

---

## 3. Escenario A: el sistema arranca

Usa este procedimiento cuando el sistema arranca aunque esté roto: Hyprland no inicia, un paquete dejó el sistema inestable, un servicio crítico falla.

Requiere acceso a la CLI por cualquiera de estas vías:

- Consola directa — el sistema arranca sin entorno gráfico y obtienes el login en texto
- TTY alternativo — si Hyprland inicia pero falla, presiona `Ctrl+Alt+F2` para abrir un TTY limpio
- SSH desde otra máquina — si la red funciona y `sshd` está activo

### 3.1 Usar el helper btrfs-rollback (MÉTODO PRINCIPAL)

Durante la instalación, `install-base.sh` instaló `/usr/local/bin/btrfs-rollback`, un helper que automatiza el rollback en una sola línea.

**Paso 1: Listar snapshots disponibles**

```bash
sudo snapper -c root list
```

Anota el número `#` del snapshot al que quieres volver.

**Paso 2: Ejecutar el rollback**

Sustituye `N` por el número del snapshot objetivo:

```bash
sudo btrfs-rollback N
```

El script:
- Monta automáticamente el pool BTRFS
- Muestra un listado legible de snapshots disponibles
- Pide confirmación antes de hacer cambios
- Hace backup automático: renombra `@` → `@_old_TIMESTAMP`
- Restaura el snapshot como nuevo `@`
- Actualiza el default subvolume
- Desmonta el pool

**Paso 3: Reiniciar**

```bash
sudo reboot
```

El sistema arrancará desde el estado del snapshot. **No elimines `@_old_TIMESTAMP` todavía** — es tu red de seguridad. Si el snapshot restaurado resulta ser el equivocado o no arranca correctamente, sigue la sección 3.2 para restaurar desde el backup.

### 3.2 Fallback manual (si btrfs-rollback no está disponible)

Si por alguna razón `btrfs-rollback` no funciona, puedes hacer el rollback manualmente con los mismos pasos que hace el helper:

**Montar el pool BTRFS:**

```bash
sudo mkdir -p /tmp/btrfs
sudo mount -o subvolid=5 /dev/nvme0n1p2 /tmp/btrfs
```

**Renombrar el subvolumen actual:**

```bash
sudo mv /tmp/btrfs/@ /tmp/btrfs/@_old_$(date +%Y%m%d_%H%M%S)
```

**Crear el nuevo @ desde el snapshot:**

Sustituye `N` por el número del snapshot objetivo:

```bash
sudo btrfs subvolume snapshot /tmp/btrfs/@snapshots/N/snapshot /tmp/btrfs/@
```

**Actualizar el default subvolume:**

```bash
NEW_ID=$(sudo btrfs subvolume list /tmp/btrfs | awk '$NF=="@" {print $2}')
sudo btrfs subvolume set-default "$NEW_ID" /tmp/btrfs
```

**Desmontar y reiniciar:**

```bash
sudo umount /tmp/btrfs
sudo reboot
```

---

## 4. Escenario B: el sistema no arranca

Usa este procedimiento cuando el sistema no llega al login: pantalla negra después de GRUB, kernel panic, initramfs falla.

### 4.1 Arrancar desde el Live USB

Inserta el Live USB de CachyOS y arranca desde él.

### 4.2 Montar el pool BTRFS

```bash
mount -o subvolid=5 /dev/nvme0n1p2 /mnt
```

### 4.3 Identificar el snapshot objetivo

```bash
btrfs subvolume list /mnt
```

Busca las líneas con `path @snapshots/N/snapshot`. Si necesitas leer la descripción de cada snapshot:

```bash
cat /mnt/@snapshots/N/info.xml
```

El campo `<description>` muestra el nombre que snapper le asignó.

### 4.4 Renombrar el subvolumen roto

```bash
mv /mnt/@ /mnt/@.broken
```

### 4.5 Crear el nuevo @ desde el snapshot

```bash
btrfs subvolume snapshot /mnt/@snapshots/N/snapshot /mnt/@
```

### 4.6 Desmontar y reiniciar

```bash
umount /mnt
reboot
```

Retira el USB. El sistema arrancará desde el estado del snapshot con el mismo kernel que estaba incluido en él. **No elimines `@.broken` todavía** — espera a confirmar que el sistema funciona correctamente antes de limpiarlo (sección 5).

---

## 5. Limpieza post-rollback

### 5.1 Confirmar el estado del sistema

Una vez que el sistema arranca correctamente:

```bash
snapper -c root list
```

Revisa que los paquetes y configuraciones corresponden al snapshot restaurado.

### 5.2 Eliminar el backup del subvolumen anterior

Si usaste `btrfs-rollback`, el backup está en `@_old_YYYYMMDD_HHMMSS`. Si todo funciona correctamente, elimínalo:

```bash
sudo mount -o subvolid=5 /dev/nvme0n1p2 /tmp/btrfs
```

```bash
sudo btrfs subvolume delete /tmp/btrfs/@_old_*
```

```bash
sudo umount /tmp/btrfs
```

Si hiciste rollback manual, elimina `@.broken` con el mismo procedimiento (sustituye `@_old_*` por `@.broken`).

### 5.3 Eliminar snapshots innecesarios

Los snapshots del sistema roto ya no son útiles. Elimínalos con snapper:

```bash
sudo snapper -c root delete N
```

Para eliminar un rango:

```bash
sudo snapper -c root delete N-M
```

Snapper elimina el subvolumen y actualiza `/.snapshots`. `grub-btrfsd` detecta el cambio y regenera el menú de GRUB automáticamente.

---

## 6. Verificar el GRUB tras la limpieza

```bash
systemctl status grub-btrfsd | grep "Grub submenu"
```

Resultado esperado:

```text
grub-btrfsd[...]: Grub submenu recreated
```

---

## Recomendación: snapshot manual antes de cambios riesgosos

Antes de instalar un entorno gráfico, actualizar el kernel o cualquier cambio significativo, toma un snapshot manual con descripción clara:

```bash
sudo snapper -c root create --description "pre-instalacion-hyprland"
```

Verifica que se creó:

```bash
snapper -c root list
```

Tener un snapshot con nombre descriptivo antes del cambio hace que la sección 1 de este capítulo sea trivial — ya sabes exactamente a cuál número volver.

---

## Estado esperado al completar un rollback

- El sistema arranca desde el subvolumen `@` que corresponde al snapshot restaurado.
- El subvolumen `@.broken` fue eliminado del pool.
- Los snapshots innecesarios fueron eliminados con snapper.
- El menú de GRUB refleja los snapshots actuales.

---

← [Cap. 10 — Primer arranque](Capítulo-10-Primer-arranque.md) · [Índice](..) · [Cap. 12 — Instalación Hyprland](Capítulo-12-Instalacion-Hyprland.md) →
