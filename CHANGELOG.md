# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Con LUKS, el asistente de la instalación base pregunta si el disco y el usuario usan la misma clave (por defecto No; nunca hay inicio de sesión automático). Con «Sí» queda instalado el comando `sudo cambiar-clave`, que cambia la clave del disco y la contraseña del usuario a la vez: agrega la clave nueva antes de quitar la vieja, comprueba cada paso y deshace el cambio si algo falla. `base/probar-cambiar-clave.sh` lo prueba con un archivo cifrado real.
- El asistente de la instalación base pide el nombre completo del usuario y lo guarda en el campo de comentario de la cuenta.
- Cada pregunta del asistente de la instalación base tiene el botón Atrás, que vuelve a la pregunta anterior con la respuesta ya dada marcada; Esc pregunta si se quiere salir del instalador, y el resumen final es un menú que permite ir directo a cualquier pregunta antes de confirmar.
- La instalación base consulta una sola vez a `ipinfo.io` (la IP pública sale hacia ese servicio, con un máximo de 5 segundos y sin guardar la respuesta) para detectar la zona horaria: la zona detectada aparece en el menú como `(Recomendada)` y queda seleccionada. Si no hay respuesta, el menú aparece sin recomendación.
- El menú de idioma del sistema de la instalación base recomienda el idioma según el país que devuelve esa misma consulta a `ipinfo.io`: el idioma de la lista que corresponde a ese país aparece como `(Recomendada)` y queda seleccionado, y ya no hay un idioma fijo marcado como recomendado. Si el país no coincide con ningún idioma de la lista, o no se pudo detectar, el menú aparece sin recomendación.
- El menú de teclado de la instalación base recomienda la distribución según el idioma elegido en la pregunta anterior: si el país del idioma coincide con una distribución de la lista (`us`, `es`, `fr`, `de`, `pt`) aparece esa como `(Recomendada)` y queda seleccionada, y si el idioma es español y el país no es España se recomienda `latam`. Con cualquier otro idioma el menú aparece sin recomendación.
- El resumen de la instalación base pide una última confirmación antes de borrar el disco: al elegir «Confirmar la instalación» pregunta si se está seguro de borrar todos los datos del disco, con «No» como botón por defecto; «No» vuelve al resumen.
- La instalación base descarga el repositorio en `/home/<usuario>/cachyos-install` y, en el primer inicio de sesión, muestra un aviso una sola vez con el comando `cd ~/cachyos-install && ./install.sh` para continuar. Si la descarga falla, avisa y la instalación continúa sin el aviso.

### Fixed

- Las contraseñas del asistente de la instalación base se escribían con un teclado distinto al del sistema instalado (la consola del instalador quedaba con un teclado fijo y el teclado se elegía después de la contraseña del usuario), por lo que una clave con símbolos podía no aceptarse al arrancar o al iniciar sesión. Ahora el teclado se pregunta antes de cualquier nombre o contraseña, se carga en la consola del instalador, las pantallas de contraseña indican el teclado activo y, si el teclado cambia, las contraseñas se piden de nuevo.
- El menú de selección de disco de la instalación base no respondía al teclado cuando se lanzaba desde `install.sh`; ahora el instalador base corre bajo `script` en vez de un pipe a `tee`.
- El instalador de aplicaciones de Hyprland abortaba sin root porque escribía su log en /var/log; ahora lo escribe junto al script (hyprland/install-hyprland-apps.log, ignorado por git).

### Changed

- El resumen de la instalación base se muestra dentro del cuadro de diálogo, con la ayuda a la vista y solo dos opciones: «Confirmar la instalación» y «¿Deseas modificar alguna opción?». La segunda abre la lista de preguntas, con «Volver al resumen» y «Salir del instalador»; al cambiar una pregunta se vuelve al resumen con el valor nuevo.
- El menú de `install.sh` ya no pide la segunda confirmación («Confirmación final») antes de la instalación base: quedan el aviso crítico del inicio y la última confirmación del resumen, que nombra el disco que se borrará.
- Cancelar en las preguntas del asistente de la instalación base ya no asigna un valor por defecto: cada respuesta es la que el usuario eligió.
- El asistente de la instalación base ya no limpia el disco (`wipefs -a`) al elegirlo: solo avisa si tiene datos previos, y no se borra nada hasta la confirmación final.
- Licencia cambiada de AGPL-3.0 a GPL-3.0; se conserva el aviso MIT de Omarchy en `THIRD-PARTY-LICENSES.md`.
