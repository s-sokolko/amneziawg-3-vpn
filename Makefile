COMPOSE = docker compose
SERVICE = awg

.PHONY: init up down restart build logs shell add rm ls qr prune rebuild

init:
ifndef PUBLIC_IP
	$(error Usage: make init PUBLIC_IP=<ip_or_domain> [POLICY=build|pull] [PORT=<udp_port>])
endif
	@POLICY_VAL="$(POLICY)"; \
	[ -z "$$POLICY_VAL" ] && POLICY_VAL=pull; \
	case "$$POLICY_VAL" in \
		build|pull) ;; \
		*) echo "POLICY must be 'build' or 'pull', got: '$$POLICY_VAL'" >&2; exit 1 ;; \
	esac; \
	if [ -f .env ]; then \
		echo "[*] .env already exists, template .env.example.$$POLICY_VAL is not applied (only PUBLIC_ENDPOINT/PORT are updated below)"; \
	else \
		cp .env.example.$$POLICY_VAL .env; \
		echo "[*] .env created from .env.example.$$POLICY_VAL"; \
	fi
	@sed -i "s/^PUBLIC_ENDPOINT=.*/PUBLIC_ENDPOINT=$(PUBLIC_IP)/" .env
ifdef PORT
	@sed -i "s/^LISTEN_PORT=.*/LISTEN_PORT=$(PORT)/" .env
	@echo "[*] LISTEN_PORT set explicitly: $(PORT)"
else
	@if [ -z "$$(grep '^LISTEN_PORT=' .env | cut -d= -f2)" ]; then \
		RANDPORT=$$(shuf -i 20000-60000 -n1); \
		sed -i "s/^LISTEN_PORT=.*/LISTEN_PORT=$$RANDPORT/" .env; \
		echo "[*] LISTEN_PORT generated: $$RANDPORT"; \
	else \
		echo "[*] LISTEN_PORT is already set in .env, leaving it as is: $$(grep '^LISTEN_PORT=' .env | cut -d= -f2)"; \
	fi
endif
	@echo "[*] Done: PUBLIC_ENDPOINT=$(PUBLIC_IP) -> now you can run: make up"

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

start:
	$(COMPOSE) start

stop:
	$(COMPOSE) stop

restart:
	$(COMPOSE) restart

build:
	$(COMPOSE) build

rebuild:
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d

pull:
	$(COMPOSE) pull

logs:
	$(COMPOSE) logs -f $(SERVICE)

shell:
	$(COMPOSE) exec $(SERVICE) bash

add:
ifndef NAME
	$(error Usage: make add NAME=<client_name>)
endif
	$(COMPOSE) exec $(SERVICE) add-client.sh $(NAME)

rm:
ifndef NAME
	$(error Usage: make rm NAME=<client_name>)
endif
	$(COMPOSE) exec $(SERVICE) remove-client.sh $(NAME)

ls:
	$(COMPOSE) exec $(SERVICE) list-clients.sh

qr:
ifndef NAME
	$(error Usage: make qr NAME=<client_name>)
endif
	$(COMPOSE) exec $(SERVICE) sh -c "qrencode -t ansiutf8 < /etc/amnezia/amneziawg/clients/$(NAME).conf"

prune:
	@echo "WARNING: this will remove the container, the built image and ALL data in ./data"
	@echo "(the server and all client keys will be lost permanently)."
	@read -p "Continue? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		$(COMPOSE) down -v --rmi local --remove-orphans; \
		sudo rm -rf ./data; \
		echo "[*] Removed: container, image, ./data"; \
	else \
		echo "Cancelled"; \
	fi
