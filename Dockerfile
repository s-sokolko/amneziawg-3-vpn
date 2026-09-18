ARG DEBIAN_CODENAME=bookworm
ARG GO_VERSION=1.25

FROM golang:${GO_VERSION}-${DEBIAN_CODENAME} AS builder
RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential libmnl-dev pkg-config \
    && rm -rf /var/lib/apt/lists/*

ARG AWG_GO_REF=master
ARG AWG_TOOLS_REF=master

RUN git clone --depth 1 --branch "$AWG_GO_REF" https://github.com/amnezia-vpn/amneziawg-go /src/awg-go \
    && cd /src/awg-go && make

RUN git clone --depth 1 --branch "$AWG_TOOLS_REF" https://github.com/amnezia-vpn/amneziawg-tools /src/awg-tools \
    && cd /src/awg-tools/src \
    && make \
    && make install DESTDIR=/staging PREFIX=/usr

FROM debian:${DEBIAN_CODENAME}-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 iptables iputils-ping qrencode bash grep gawk coreutils \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/awg-go/amneziawg-go /usr/bin/amneziawg-go
COPY --from=builder /staging/usr/bin/awg /usr/bin/awg
COPY --from=builder /staging/usr/bin/awg-quick /usr/bin/awg-quick
RUN chmod +x /usr/bin/awg-quick /usr/bin/awg /usr/bin/amneziawg-go

COPY scripts/ /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

VOLUME /etc/amnezia/amneziawg

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD awg show awg0 > /dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
