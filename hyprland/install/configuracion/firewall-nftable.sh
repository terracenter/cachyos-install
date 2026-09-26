#!/bin/bash
step "Configurando Firewall Robusto (nftables)..."

info "Instalando paquete nftables..."
sudo pacman -S --needed --noconfirm nftables > /dev/null 2>&1 || warn "Falló la instalación de nftables (quizás ya estaba)"

info "Generando configuración blindada en /etc/nftables.conf..."
sudo tee /etc/nftables.conf > /dev/null << 'NFT_EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet sm {
    chain input {
        type filter hook input priority filter; policy drop;

        # 1. Permitir tráfico de la interfaz local (loopback)
        iifname "lo" accept

        # 2. Permitir conexiones entrantes de conexiones ya establecidas o relacionadas
        ct state established,related accept

        # 3. Descartar paquetes inválidos por seguridad
        ct state invalid drop

        # 4. Permitir ICMP (Ping) con límite de tasa para evitar inundaciones
        ip protocol icmp icmp type echo-request limit rate 5/second accept
        ip6 nexthdr icmpv6 icmpv6 type echo-request limit rate 5/second accept

        # ======================================================================
        # ZONA DE REGLAS PERSONALIZADAS (Agrega tus puertos aquí)
        # ======================================================================
        # Ejemplo para permitir SSH (Descomentar la línea de abajo si necesitas SSH entrante):
        # tcp dport 22 accept
        #
        # Ejemplo para permitir HTTP/HTTPS local:
        # tcp dport { 80, 443 } accept
        #
        # Ejemplo para permitir Syncthing:
        # tcp dport 22000 accept
        # udp dport 21027 accept
        # ======================================================================
    }

    chain forward {
        type filter hook forward priority filter; policy drop;
    }

    chain output {
        type filter hook output priority filter; policy accept;
    }
}
NFT_EOF

# Asegurar permisos correctos
sudo chmod 644 /etc/nftables.conf

# Validar sintaxis antes de aplicar
if sudo nft -c -f /etc/nftables.conf; then
    ok "Sintaxis de nftables validada con éxito"
    # Habilitar y arrancar el servicio
    sudo systemctl enable --now nftables.service 2>/dev/null || true
    ok "Firewall nftables activado y blindado"
else
    warn "Error en la sintaxis de nftables. Revisa /etc/nftables.conf"
fi
