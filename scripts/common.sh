#!/bin/bash
IFACE=awg0
CONF_DIR=/etc/amnezia/amneziawg
CONF="$CONF_DIR/$IFACE.conf"
CLIENTS_DIR="$CONF_DIR/clients"

: "${SERVER_SUBNET_BASE:=10.8.1}"
: "${CLIENT_DNS:=1.1.1.1}"
: "${EXTERNAL_IFACE:=eth0}"   # интерфейс внутри контейнера — почти всегда eth0

server_pubkey() {
    grep '^PrivateKey' "$CONF" | cut -d' ' -f3 | awg pubkey
}

server_listen_port() {
    grep '^ListenPort' "$CONF" | cut -d' ' -f3
}

used_octets() {
    grep -oP "AllowedIPs = ${SERVER_SUBNET_BASE}\.\K[0-9]+" "$CONF" 2>/dev/null
}

next_free_octet() {
    local used
    used=$(used_octets)
    for i in $(seq 2 254); do
        if ! grep -qx "$i" <<< "$used"; then
            echo "$i"
            return
        fi
    done
    echo "Нет свободных адресов в подсети" >&2
    exit 1
}

client_exists() {
    grep -q "^### $1$" "$CONF" 2>/dev/null
}

obfuscation_params() {
    grep -E '^(Jc|Jmin|Jmax|S1|S2|S3|S4|H1|H2|H3|H4|HeaderProtectionKey|ContentPaddingAddition|RekeyAfterTime|RekeyTimeout|RejectAfterTime|KeepaliveTimeout|MaxHandshakeAttempts|RandomTrailers|DisableCookies) *=' "$CONF"
}

