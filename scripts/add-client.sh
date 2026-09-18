#!/bin/bash
set -e
source /usr/local/bin/common.sh

NAME=$1
[ -z "$NAME" ] && { echo "Usage: add-client.sh <name>"; exit 1; }
client_exists "$NAME" && { echo "Client '$NAME' already exists"; exit 1; }

OCTET=$(next_free_octet)
IP="${SERVER_SUBNET_BASE}.${OCTET}"

PRIV=$(awg genkey)
PUB=$(echo "$PRIV" | awg pubkey)
PSK=$(awg genpsk)

awg set "$IFACE" peer "$PUB" preshared-key <(echo "$PSK") allowed-ips "${IP}/32"

cat >> "$CONF" <<EOF

### $NAME
[Peer]
PublicKey = $PUB
PresharedKey = $PSK
AllowedIPs = ${IP}/32
EOF

: "${PUBLIC_ENDPOINT:?PUBLIC_ENDPOINT is not set in .env}"
SPUB=$(server_pubkey)
PORT=$(server_listen_port)

{
  echo "[Interface]"
  echo "Address = ${IP}/32"
  echo "DNS = $CLIENT_DNS"
  echo "PrivateKey = $PRIV"
  obfuscation_params
  echo ""
  echo "[Peer]"
  echo "PublicKey = $SPUB"
  echo "PresharedKey = $PSK"
  echo "AllowedIPs = 0.0.0.0/0, ::/0"
  echo "Endpoint = ${PUBLIC_ENDPOINT}:${PORT}"
  echo "PersistentKeepalive = 25"
} > "$CLIENTS_DIR/$NAME.conf"

echo "[*] Client '$NAME' created: $CLIENTS_DIR/$NAME.conf ($IP)"

