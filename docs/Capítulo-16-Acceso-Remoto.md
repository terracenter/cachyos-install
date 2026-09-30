# Capítulo 16: Acceso remoto

[← Cap. 15: Gestión de paquetes](Capítulo-15-Gestion-Paquetes.md) · [Índice](./_index.md) · [Cap. 17: Herramientas CLI →](Capítulo-17-Herramientas-CLI-modernas.md)

## Alcance

El acceso remoto no forma parte del escritorio Hyprland base. Debe habilitarse solo cuando exista una necesidad concreta y aplicando controles de autenticación, red y firewall.

## OpenSSH

El instalador base instala y habilita `sshd`. Comprueba su estado:

```bash
systemctl is-enabled sshd
systemctl status sshd
```

Si no necesitas acceso remoto:

```bash
sudo systemctl disable --now sshd
```

### Validar la configuración

Antes de recargar el servicio:

```bash
sudo sshd -t
```

Una configuración válida no produce salida.

### Claves SSH

Genera una clave en el cliente:

```bash
ssh-keygen -t ed25519
```

Cópiala al equipo remoto:

```bash
ssh-copy-id usuario@equipo
```

Prueba la conexión antes de desactivar contraseñas:

```bash
ssh usuario@equipo
```

Después puedes crear un archivo en `/etc/ssh/sshd_config.d/` para restringir usuarios y autenticación. Conserva una sesión administrativa abierta durante la prueba para evitar perder acceso.

## Acceso a la sesión Wayland

WayVNC comparte una salida Wayland existente. No crea por sí solo una sesión completa ni utiliza automáticamente la autenticación PAM del usuario.

Antes de instalarlo, comprueba si está disponible en un repositorio configurado:

```bash
pacman -Si wayvnc
```

Si está disponible:

```bash
sudo pacman -S wayvnc
```

No lo añadas al autostart global sin definir previamente autenticación, interfaz de escucha y política de red.

## Túnel SSH

Una opción más segura que exponer VNC a toda la red es limitar el servidor a localhost y acceder mediante un túnel SSH.

En el cliente:

```bash
ssh -L 5900:127.0.0.1:5900 usuario@equipo
```

Después conecta el visor VNC del cliente a:

```text
127.0.0.1:5900
```

El túnel cifra el transporte, pero no reemplaza la seguridad de SSH, las claves, el firewall ni la autenticación del servicio remoto.

## Firewall

No abras el puerto VNC a Internet. Si necesitas acceso fuera de la red local, utiliza una VPN administrada o un túnel SSH con autenticación por claves.

Comprueba puertos escuchando:

```bash
ss -lntp
```

Comprueba reglas del firewall configurado en el sistema antes de aceptar conexiones remotas.

## Herramientas de terceros

Aplicaciones como AnyDesk deben considerarse opcionales. No habilites su servicio si solo necesitas utilizarlas como cliente. Revisa sus limitaciones bajo Wayland, permisos y política de privacidad antes de instalarlas.

## Lista de comprobación

- `sshd -t` termina sin errores.
- El usuario puede entrar con una clave SSH.
- Solo los usuarios autorizados tienen acceso.
- VNC no escucha públicamente sin protección.
- El firewall limita la exposición.
- Los servicios remotos innecesarios permanecen deshabilitados.
- Existe una forma local de recuperación si falla la configuración.

## Referencias

- OpenSSH en ArchWiki: <https://wiki.archlinux.org/title/OpenSSH>
- WayVNC: <https://github.com/any1/wayvnc>
- TigerVNC y túneles SSH: <https://wiki.archlinux.org/title/TigerVNC>
