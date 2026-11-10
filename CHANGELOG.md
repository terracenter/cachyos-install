# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- El asistente de la instalación base pide el nombre completo del usuario y lo guarda en el campo de comentario de la cuenta.
- Cada pregunta del asistente de la instalación base tiene el botón Atrás, que vuelve a la pregunta anterior con la respuesta ya dada marcada; Esc pregunta si se quiere salir del instalador, y el resumen final es un menú que permite ir directo a cualquier pregunta antes de confirmar.
- La instalación base consulta una sola vez a `ipinfo.io` (la IP pública sale hacia ese servicio, con un máximo de 5 segundos y sin guardar la respuesta) para detectar la zona horaria: la zona detectada aparece en el menú como `(Recomendada)` y queda seleccionada. Si no hay respuesta, el menú aparece sin recomendación.
- El menú de idioma del sistema de la instalación base recomienda el idioma según el país que devuelve esa misma consulta a `ipinfo.io`: el idioma de la lista que corresponde a ese país aparece como `(Recomendada)` y queda seleccionado, y ya no hay un idioma fijo marcado como recomendado. Si el país no coincide con ningún idioma de la lista, o no se pudo detectar, el menú aparece sin recomendación.
- El menú de teclado de la instalación base recomienda la distribución según el idioma elegido en la pregunta anterior: si el país del idioma coincide con una distribución de la lista (`us`, `es`, `fr`, `de`, `pt`) aparece esa como `(Recomendada)` y queda seleccionada, y si el idioma es español y el país no es España se recomienda `latam`. Con cualquier otro idioma el menú aparece sin recomendación.
- El resumen de la instalación base pide una última confirmación antes de borrar el disco: al elegir «CONFIRMAR E INSTALAR» pregunta si se está seguro de borrar todos los datos del disco, con «No» como botón por defecto; «No» vuelve al resumen.

### Fixed

- El menú de selección de disco de la instalación base no respondía al teclado cuando se lanzaba desde `install.sh`; ahora el instalador base corre bajo `script` en vez de un pipe a `tee`.
- El instalador de aplicaciones de Hyprland abortaba sin root porque escribía su log en /var/log; ahora lo escribe junto al script (hyprland/install-hyprland-apps.log, ignorado por git).

### Changed

- Cancelar en las preguntas del asistente de la instalación base ya no asigna un valor por defecto: cada respuesta es la que el usuario eligió.
- El asistente de la instalación base ya no limpia el disco (`wipefs -a`) al elegirlo: solo avisa si tiene datos previos, y no se borra nada hasta la confirmación final.
- Licencia cambiada de AGPL-3.0 a GPL-3.0; se conserva el aviso MIT de Omarchy en `THIRD-PARTY-LICENSES.md`.
