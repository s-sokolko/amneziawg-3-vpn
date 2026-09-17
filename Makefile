COMPOSE = docker compose
SERVICE = awg

.PHONY: init up down restart build logs shell add rm ls qr prune rebuild

init:
ifndef PUBLIC_IP
	$(error Использование: make init PUBLIC_IP=<ip_или_домен> [PORT=<udp_порт>])
endif
	@[ -f .env ] || cp .env.example .env
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
	@echo "[*] PUBLIC_ENDPOINT=$(PUBLIC_IP) записан в .env — готово, можно: make up"


up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart

build:
	$(COMPOSE) build

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

rebuild:
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d

