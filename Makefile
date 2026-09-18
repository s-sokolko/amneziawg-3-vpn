COMPOSE = docker compose
SERVICE = awg

.PHONY: init up down restart build logs shell add rm ls qr prune rebuild

init:
ifndef PUBLIC_IP
	$(error Использование: make init PUBLIC_IP=<ip_или_домен> [POLICY=build|pull] [PORT=<udp_порт>])
endif
	@POLICY_VAL="$(POLICY)"; \
	[ -z "$$POLICY_VAL" ] && POLICY_VAL=pull; \
	case "$$POLICY_VAL" in \
		build|pull) ;; \
		*) echo "POLICY должен быть 'build' или 'pull', получено: '$$POLICY_VAL'" >&2; exit 1 ;; \
	esac; \
	if [ -f .env ]; then \
		echo "[*] .env уже существует, шаблон .env.example.$$POLICY_VAL не применяется (только PUBLIC_ENDPOINT/PORT обновятся ниже)"; \
	else \
		cp .env.example.$$POLICY_VAL .env; \
		echo "[*] .env создан из .env.example.$$POLICY_VAL"; \
	fi
	@sed -i "s/^PUBLIC_ENDPOINT=.*/PUBLIC_ENDPOINT=$(PUBLIC_IP)/" .env
ifdef PORT
	@sed -i "s/^LISTEN_PORT=.*/LISTEN_PORT=$(PORT)/" .env
	@echo "[*] LISTEN_PORT задан явно: $(PORT)"
else
	@if [ -z "$$(grep '^LISTEN_PORT=' .env | cut -d= -f2)" ]; then \
		RANDPORT=$$(shuf -i 20000-60000 -n1); \
		sed -i "s/^LISTEN_PORT=.*/LISTEN_PORT=$$RANDPORT/" .env; \
		echo "[*] LISTEN_PORT сгенерирован: $$RANDPORT"; \
	else \
		echo "[*] LISTEN_PORT уже задан в .env, не трогаю: $$(grep '^LISTEN_PORT=' .env | cut -d= -f2)"; \
	fi
endif
	@echo "[*] Готово: PUBLIC_ENDPOINT=$(PUBLIC_IP) → можно: make up"

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
	$(error Использование: make add NAME=<имя_клиента>)
endif
	$(COMPOSE) exec $(SERVICE) add-client.sh $(NAME)

rm:
ifndef NAME
	$(error Использование: make rm NAME=<имя_клиента>)
endif
	$(COMPOSE) exec $(SERVICE) remove-client.sh $(NAME)

ls:
	$(COMPOSE) exec $(SERVICE) list-clients.sh

qr:
ifndef NAME
	$(error Использование: make qr NAME=<имя_клиента>)
endif
	$(COMPOSE) exec $(SERVICE) sh -c "qrencode -t ansiutf8 < /etc/amnezia/amneziawg/clients/$(NAME).conf"

prune:
	@echo "ВНИМАНИЕ: это удалит контейнер, собранный образ и ВСЕ данные в ./data"
	@echo "(ключи сервера и всех клиентов будут потеряны безвозвратно)."
	@read -p "Продолжить? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		$(COMPOSE) down -v --rmi local --remove-orphans; \
		sudo rm -rf ./data; \
		echo "[*] Удалено: контейнер, образ, ./data"; \
	else \
		echo "Отменено"; \
	fi
