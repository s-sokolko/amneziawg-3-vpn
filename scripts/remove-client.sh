#!/bin/bash
set -e
source /usr/local/bin/common.sh

NAME=$1
[ -z "$NAME" ] && { echo "Использование: remove-client.sh <имя>"; exit 1; }
client_exists "$NAME" || { echo "Клиент '$NAME' не найден"; exit 1; }

PUB=$(awk "/^### $NAME\$/{f=1} f && /^PublicKey/{print \$3; exit}" "$CONF")
awg set "$IFACE" peer "$PUB" remove

awk -v name="### $NAME" '
    BEGIN{skip=0}
    $0==name{skip=1; next}
    skip && /^$/{skip=0; next}
    !skip{print}
' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"

rm -f "$CLIENTS_DIR/$NAME.conf"
echo "[*] Клиент '$NAME' удалён"

