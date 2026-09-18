#!/bin/bash
set -e
source /usr/local/bin/common.sh

mkdir -p "$CLIENTS_DIR"
umask 077

rand_int() { echo $(( $1 + RANDOM % ($2 - $1 + 1) )); }

gen_S_values() {
    while true; do
        S1=$(rand_int 12 200); S2=$(rand_int 12 200)
        S3=$(rand_int 12 200); S4=$(rand_int 12 200)
        [ $((S1 + 148)) -ne $((S2 + 92)) ] && break
    done
}

if [ ! -f "$CONF" ]; then
    echo "[*] First run: generating random server parameters"

    PRIV=$(awg genkey)
    HPK=$(awg genkey)

    # LISTEN_PORT must already be set at this point - `make init` pins it in .env,
    # because compose needs to know the port to publish in advance.
    : "${LISTEN_PORT:?LISTEN_PORT is not set - run make init}"

    JC=$(rand_int 4 12)
    JMIN=$(rand_int 10 40)
    JMAX=$(rand_int $((JMIN + 50)) 500)

    gen_S_values

    # H1-H4 are intentionally fixed (not randomized): with Header Protection
    # enabled (HeaderProtectionKey is set) the documentation recommends keeping
    # them at "compatible" values - the packet type is already hidden by
    # Header Protection.
    H1=1; H2=2; H3=3; H4=4

    CPA_LOW=$(rand_int 20 50); CPA_HIGH=$(rand_int $((CPA_LOW+20)) 120)
    RAT_LOW=$(rand_int 90 130); RAT_HIGH=$(rand_int $((RAT_LOW+10)) 170)
    RTO_LOW=$(rand_int 4 8); RTO_HIGH=$(rand_int $((RTO_LOW+2)) 15)
    RJT_LOW=$(rand_int 150 190); RJT_HIGH=$(rand_int $((RJT_LOW+10)) 230)
    KAT_LOW=$(rand_int 8 15); KAT_HIGH=$(rand_int $((KAT_LOW+5)) 30)
    MHA_LOW=$(rand_int 10 18); MHA_HIGH=$(rand_int $((MHA_LOW+2)) 25)

    cat > "$CONF" <<EOF
[Interface]
PrivateKey = $PRIV
Address = ${SERVER_SUBNET_BASE}.1/24
ListenPort = $LISTEN_PORT
Jc = $JC
Jmin = $JMIN
Jmax = $JMAX
S1 = $S1
S2 = $S2
S3 = $S3
S4 = $S4
H1 = $H1
H2 = $H2
H3 = $H3
H4 = $H4
HeaderProtectionKey = $HPK
ContentPaddingAddition = ${CPA_LOW}-${CPA_HIGH}
RekeyAfterTime = ${RAT_LOW}-${RAT_HIGH}
RekeyTimeout = ${RTO_LOW}-${RTO_HIGH}
RejectAfterTime = ${RJT_LOW}-${RJT_HIGH}
KeepaliveTimeout = ${KAT_LOW}-${KAT_HIGH}
MaxHandshakeAttempts = ${MHA_LOW}-${MHA_HIGH}
RandomTrailers = on
PostUp = iptables -t nat -A POSTROUTING -o $EXTERNAL_IFACE -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o $EXTERNAL_IFACE -j MASQUERADE
EOF
    echo "[*] Config created: $CONF (port $LISTEN_PORT, NAT interface: $EXTERNAL_IFACE)"
else
    echo "[*] Using existing config: $CONF"
fi

cleanup() {
    echo "[*] Bringing down interface $IFACE"
    awg-quick down "$CONF" || true
    exit 0
}
trap cleanup SIGTERM SIGINT

echo "[*] Bringing up interface $IFACE"
awg-quick up "$CONF"

tail -f /dev/null &
wait $!

