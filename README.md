# AmneziaWG Go — Self-Hosted AmneziaWG 3.1 VPN Server

A self-contained, Docker-based AmneziaWG **3.1** server — the DPI-resistant,
obfuscated WireGuard fork — with client management driven entirely through a
`Makefile`. No web UI, no external orchestration, no Ansible required for a
single server.

This repository is **fully self-contained**: it includes everything needed to
build the server from source yourself (`amneziawg-go` + `amneziawg-tools`,
compiled from the official upstream repositories). You don't have to trust a
prebuilt image — a ready-made one is provided on Docker Hub for convenience,
but you can build your own from the exact same Dockerfile at any time.
Because building from source is a first-class path here, you always get the
**latest upstream AmneziaWG 3.1 code** rather than whatever happens to be
frozen in someone else's stale image.

## Highlights

- **AmneziaWG 3.1 always on** — header protection, random trailers, disabled
  cookies, junk packets and padding. All obfuscation parameters
  (`Jc/Jmin/Jmax`, `S1-S4`, `HeaderProtectionKey`, timing jitter, etc.) are
  **randomly generated per-deployment** on first start, not hardcoded — so
  your server doesn't share a fingerprint with every other install using the
  same defaults.
- **Two deployment modes, your choice**: pull a prebuilt image from Docker
  Hub in seconds, or build everything from source on your own machine —
  switchable with a single flag.
- **No kernel module needed** — runs entirely in userspace
  (`amneziawg-go` + TUN), so it works on any VPS without custom kernels.
- **All host tuning lives in `docker-compose.yml`** (`sysctls`, capabilities,
  NAT) — no separate provisioning step, no Ansible, for the common case of
  one or two servers that rarely move.
- **One `Makefile`** to bring the server up, manage clients, generate QR
  codes, and tear everything down.

## Repository layout

```
.
├── Dockerfile                # multi-stage build: compiles amneziawg-go + amneziawg-tools
├── docker-compose.yml
├── .env.example.pull         # template for "use the prebuilt image" mode
├── .env.example.build        # template for "build from source" mode
├── Makefile
├── scripts/
│   ├── common.sh
│   ├── entrypoint.sh          # generates server config + obfuscation params on first run
│   ├── add-client.sh
│   ├── remove-client.sh
│   └── list-clients.sh
└── data/                      # created automatically — server config + client configs (persistent volume)
```

---

## Quick start (recommended: pull the prebuilt image)

This is the fastest path — no Go toolchain, no compilation, no need for the
server to reach GitHub at all. It uses the prebuilt image published on Docker
Hub at [`sokolko/awg-go`](https://hub.docker.com/r/sokolko/awg-go).

### 1. Install prerequisites: Docker, Compose, `make`, and `bash`

This repo is driven entirely through the `Makefile`, and the container's
scripts are written in `bash` — both need to be present on the host.

**Docker + Compose** — one command, official installer (installs Engine,
CLI, and the Compose v2 plugin together):

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker
```

**`make`** — not included on minimal/server Ubuntu images by default. Install
it with:

```bash
sudo apt update && sudo apt install -y make
```

**`bash`** — ships by default on virtually every Ubuntu install (it's the
system's default `/bin/sh`-adjacent shell), so you almost certainly already
have it. If for some reason it's missing (a stripped-down container base,
for instance):

```bash
sudo apt update && sudo apt install -y bash
```

Verify everything is in place:

```bash
docker --version
docker compose version
make --version
bash --version
```

### 2. Clone this repository

```bash
git clone <this-repo-url> awg-docker
cd awg-docker
```

### 3. Initialize and start

```bash
make init PUBLIC_IP=<your-vps-public-ip-or-domain>
make up
```

`POLICY` defaults to `pull`, so this step alone is enough — no build step,
no source code touches your VPS.

Want a specific UDP port instead of a randomly generated one?

```bash
make init PUBLIC_IP=<your-vps-public-ip-or-domain> PORT=51820
```

### 4. Add a client and get the config

```bash
make add NAME=phone1
make qr NAME=phone1
```

Scan the QR code with the AmneziaVPN Android/iOS app, or grab the file
directly from `./data/clients/phone1.conf`.

That's it — a fully obfuscated AmneziaWG 3.1 server, running.

---

## Building from source instead (if you don't want to trust the prebuilt image)

If you'd rather not rely on a binary image you didn't build yourself — a
completely reasonable stance for a censorship-circumvention tool — this
repository lets you build the exact same image locally from upstream source:

```bash
make init PUBLIC_IP=<your-vps-public-ip-or-domain> POLICY=build
make up
```

This clones and compiles
[`amneziawg-go`](https://github.com/amnezia-vpn/amneziawg-go) and
[`amneziawg-tools`](https://github.com/amnezia-vpn/amneziawg-tools) directly
from their GitHub repositories inside a multi-stage Docker build, using
whatever ref you pin in `.env` (`AWG_GO_REF`, `AWG_TOOLS_REF`, both default to
`master`). Since it always builds from the actual upstream source rather than
an image someone else assembled ahead of time, you get the current protocol
implementation rather than a potentially outdated snapshot.

Note: building requires the build host to reach `github.com`. If you're
behind restrictive network conditions, `network: host` is already set on the
build context in `docker-compose.yml` so the build uses your host's own
routing (useful if the host itself is, say, behind a working VPN or proxy
already).

---

## Configuration reference

All configuration lives in a single `.env` file, generated by `make init`
from one of the two templates below depending on `POLICY`.

| Variable             | Default (pull)     | Default (build) | Description                                                                 |
| --------------------- | ------------------- | ---------------- | ----------------------------------------------------------------------------- |
| `PUBLIC_ENDPOINT`     | *(set by `make init`)* | *(set by `make init`)* | Public IP or domain clients will connect to. Set via `PUBLIC_IP=` argument. |
| `LISTEN_PORT`         | random, or explicit  | random, or explicit | UDP port the server listens on. Set via `PORT=` argument, or auto-generated once on first `make init`. |
| `CLIENT_DNS`          | `1.1.1.1`            | `1.1.1.1`         | DNS server pushed to client configs.                                          |
| `SERVER_SUBNET_BASE`  | `10.8.1`             | `10.8.1`          | First three octets of the VPN subnet.                                        |
| `EXTERNAL_IFACE`      | `eth0`               | `eth0`            | Interface *inside the container* used for NAT (almost always `eth0` in bridge networking — no need to change this). |
| `IMAGE_NAME`          | `sokolko/awg-go`     | `awg-go`          | Image name used for both running and (if applicable) building.               |
| `IMAGE_TAG`           | `latest`             | `local`           | Image tag.                                                                    |
| `PULL_POLICY`         | `always`             | `build`           | Compose `pull_policy` — controls whether the image is pulled or built.       |
| `GO_VERSION`          | —                    | `1.25`            | Go version used in the build stage (build mode only).                        |
| `DEBIAN_CODENAME`     | —                    | `bookworm`        | Debian codename shared by both the build and runtime stage (build mode only), keeping glibc ABI consistent between them. |
| `AWG_GO_REF`          | —                    | `master`          | Git ref of `amneziawg-go` to build (build mode only).                        |
| `AWG_TOOLS_REF`       | —                    | `master`          | Git ref of `amneziawg-tools` to build (build mode only).                     |

Switching between `pull` and `build` on an already-initialized server: edit
`.env` directly (`IMAGE_NAME`, `IMAGE_TAG`, `PULL_POLICY`) and run `make up`
again — `make init` will not overwrite an existing `.env`.

---

## Makefile reference

| Command                          | Description                                                                 |
| --------------------------------- | ----------------------------------------------------------------------------- |
| `make init PUBLIC_IP=... [POLICY=build\|pull] [PORT=...]` | Create `.env` from the right template. `POLICY` defaults to `pull`. Safe to re-run — won't overwrite an existing `.env` or an already-assigned port. |
| `make up`                          | Start the server (builds or pulls according to `.env`).                     |
| `make down`                        | Stop and remove the container (keeps `./data`).                             |
| `make start` / `make stop`         | Start/stop an existing container without recreating it.                     |
| `make restart`                     | Restart the container.                                                      |
| `make build`                       | Force a (cache-aware) image build.                                          |
| `make rebuild`                     | Full `--no-cache` rebuild, then restart — use when upstream source moved but your pinned ref/Dockerfile text didn't change. |
| `make pull`                        | Pull the image from Docker Hub without starting anything.                   |
| `make add NAME=<name>`             | Create a new client, add it to the server, and write its `.conf`.           |
| `make rm NAME=<name>`              | Remove a client from the server and delete its config.                      |
| `make ls`                          | List all existing clients.                                                  |
| `make qr NAME=<name>`              | Print a client's config as a scannable QR code in the terminal.             |
| `make logs`                        | Follow the container's logs.                                                |
| `make shell`                       | Open a shell inside the running container (for debugging).                  |
| `make prune`                       | **Destructive.** Remove the container, the built image, and `./data` (all keys, all clients). Asks for confirmation. |

---

## How it works

- On first start, `entrypoint.sh` generates the server's private key,
  `HeaderProtectionKey`, and all AmneziaWG 3.1 obfuscation parameters
  (`Jc/Jmin/Jmax`, `S1-S4`, timing jitter ranges, etc.) **randomly**, then
  writes them to `/etc/amnezia/amneziawg/awg0.conf` inside the persistent
  `./data` volume. On subsequent restarts, this file already exists and is
  reused as-is — your keys and clients survive container restarts, image
  rebuilds, and host reboots.
- `make add` generates a fresh keypair and preshared key for the client,
  registers it as a peer on the live interface, appends it to the server
  config, and writes a ready-to-import `.conf` file (mirroring the server's
  obfuscation parameters, as required for the handshake to succeed) to
  `./data/clients/<name>.conf`.
- Networking runs in Docker's normal bridge mode (not `network_mode: host`):
  `net.ipv4.ip_forward` and related sysctls are set at the container level via
  `sysctls:` in `docker-compose.yml`, which is sufficient because all
  forwarding between the AmneziaWG tunnel interface and the container's own
  `eth0` happens inside the container's own network namespace. Docker's
  own NAT handles the rest on the way out to the internet.
- The only thing you ever need to back up is the `./data` directory — it
  contains the server's private key and every client's private key (client
  private keys exist *only* in the exported `.conf` files, not on the
  server in any recoverable form).

## Backup and disaster recovery

```bash
tar czf awg-backup-$(date +%F).tar.gz ./data .env
```

Restoring on a new VPS: copy `./data` and `.env` back into a fresh clone of
this repository, then `make up` — no need to re-run `make init` or
re-generate any clients.

## Security notes

- No web UI is exposed by design — the only open port is the AmneziaWG UDP
  port itself, keeping the server's attack surface (and DPI fingerprint) to
  the bare minimum.
- All server-side state stays in a bind-mounted `./data` directory you fully
  control — nothing is sent anywhere except to the clients you explicitly
  export configs for.
- If you're deploying this in a context where detection carries real risk,
  building from source (`POLICY=build`) removes the prebuilt image from your
  trust chain entirely.

## License

See [LICENSE](LICENSE) for details.
