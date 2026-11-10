# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- El asistente de la instalación base pide el nombre completo del usuario y lo guarda en el campo de comentario de la cuenta.
- Cada pregunta del asistente de la instalación base tiene el botón Atrás, que vuelve a la pregunta anterior con la respuesta ya dada marcada; Esc pregunta si se quiere salir del instalador, y el resumen final es un menú que permite ir directo a cualquier pregunta antes de confirmar.

### Fixed

- El menú de selección de disco de la instalación base no respondía al teclado cuando se lanzaba desde `install.sh`; ahora el instalador base corre bajo `script` en vez de un pipe a `tee`.
- El instalador de aplicaciones de Hyprland abortaba sin root porque escribía su log en /var/log; ahora lo escribe junto al script (hyprland/install-hyprland-apps.log, ignorado por git).

### Changed

- Cancelar en las preguntas del asistente de la instalación base ya no asigna un valor por defecto: cada respuesta es la que el usuario eligió.
- Si no se acepta limpiar un disco con datos previos, el asistente vuelve a pedir el disco en vez de terminar.
- Licencia cambiada de AGPL-3.0 a GPL-3.0; se conserva el aviso MIT de Omarchy en `THIRD-PARTY-LICENSES.md`.
