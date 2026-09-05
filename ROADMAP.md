# Roadmap

Seguimiento de trabajo pendiente y en curso para `cachyos-install`. Los ítems se promueven a un Issue o Pull Request en cuanto están lo bastante definidos como para trabajarlos; este archivo es el resumen de alto nivel, no reemplaza el detalle que vive en cada Issue/PR.

---

## En curso

| # | Descripción | Estado | Referencia |
|---|-------------|--------|------------|
| 1 | Selector de teclado por Rofi en Hyprland (paridad con Qtile) + fix de `hypr-audio-setup.desktop` con ruta hardcodeada | En revisión | [PR #1](https://github.com/terracenter/cachyos-install/pull/1) |

## Pendiente — requiere validación en hardware real

| # | Descripción | Referencia |
|---|-------------|------------|
| 2 | Volumen inconsistente entre el icono de Waybar y las teclas XF86Audio en Hyprland (control por-app-enfocada vs. sink por defecto) | [Issue #2](https://github.com/terracenter/cachyos-install/issues/2) |
| 3 | Menú Rofi "Pantalla y Energía" (`idle-settings`) no funciona correctamente en Hyprland | [Issue #3](https://github.com/terracenter/cachyos-install/issues/3) |
| 4 | Mover/intercambiar la ventana grande con `Super+Shift+←/→` no se comporta como se espera en layout dwindle (2 ventanas arriba + 1 grande abajo) | [Issue #4](https://github.com/terracenter/cachyos-install/issues/4) |

---

## Cómo se usa este roadmap

1. Un problema reportado se investiga primero en el código.
2. Si es un fix concreto y de bajo riesgo (bug claro, solución verificable sin hardware), se implementa directo como Pull Request.
3. Si requiere reproducir/validar interactivamente en una sesión Hyprland o Qtile real (menús Rofi, atajos de teclado, comportamiento del compositor), se documenta como Issue con el diagnóstico encontrado, para no aplicar cambios a ciegas sobre configuración que puede afectar sesión/energía del sistema.
4. Este archivo se actualiza cuando se abre o cierra un Issue/PR relevante.

---

## Backlog (sin issue abierto todavía)

_Vacío por ahora. Agregar aquí ideas o mejoras futuras que aún no ameritan un Issue propio._
