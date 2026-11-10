# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- El asistente de la instalación base pide el nombre completo del usuario y lo guarda en el campo de comentario de la cuenta.

### Fixed

- El menú de selección de disco de la instalación base no respondía al teclado cuando se lanzaba desde `install.sh`; ahora el instalador base corre bajo `script` en vez de un pipe a `tee`.
- El instalador de aplicaciones de Hyprland abortaba sin root porque escribía su log en /var/log; ahora lo escribe junto al script (hyprland/install-hyprland-apps.log, ignorado por git).

### Changed

- Licencia cambiada de AGPL-3.0 a GPL-3.0; se conserva el aviso MIT de Omarchy en `THIRD-PARTY-LICENSES.md`.
