SHELL := /bin/bash
.DEFAULT_GOAL := help

COMPOSE_DIR := frappe_docker
SITE_NAME := erpnext.example.com

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ---------- Init ----------

init: ## Clone frappe_docker and apply config
	@if [ -d "$(COMPOSE_DIR)" ]; then echo "frappe_docker already exists, skip clone"; else \
		git clone https://github.com/frappe/frappe_docker.git $(COMPOSE_DIR); fi
	@cp config/erpnext.env $(COMPOSE_DIR)/.env
	@mkdir -p mariadb-conf
	@cp config/mariadb-tuning.cnf mariadb-conf/
	@mkdir -p logs
	@echo "Done. Edit $(COMPOSE_DIR)/.env and run 'make up'"

# ---------- Lifecycle ----------

up: ## Start all services (docker compose up -d)
	@cd $(COMPOSE_DIR) && docker compose up -d

stop: ## Stop all services
	@cd $(COMPOSE_DIR) && docker compose stop

start: ## Start all stopped services
	@cd $(COMPOSE_DIR) && docker compose start

down: ## Stop and remove all containers
	@cd $(COMPOSE_DIR) && docker compose down

restart: stop start ## Restart all services

ps: ## Show container status
	@cd $(COMPOSE_DIR) && docker compose ps

logs: ## Tail all logs
	@cd $(COMPOSE_DIR) && docker compose logs -f --tail=100

logs-backend: ## Tail backend logs only
	@cd $(COMPOSE_DIR) && docker compose logs -f --tail=100 backend

logs-db: ## Tail database logs only
	@cd $(COMPOSE_DIR) && docker compose logs -f --tail=100 db

# ---------- Site & App ----------

create-site: ## Create a new Frappe site
	@cd $(COMPOSE_DIR) && docker compose exec backend bench new-site $(SITE_NAME) --admin-password "admin"

install-erpnext: ## Install ERPNext app on the site
	@cd $(COMPOSE_DIR) && docker compose exec backend bench --site $(SITE_NAME) install-app erpnext

migrate: ## Run site migration
	@cd $(COMPOSE_DIR) && docker compose exec backend bench --site $(SITE_NAME) migrate

clear-cache: ## Clear site cache
	@cd $(COMPOSE_DIR) && docker compose exec backend bench --site $(SITE_NAME) clear-cache

doctor: ## Run site health check
	@cd $(COMPOSE_DIR) && docker compose exec backend bench --site $(SITE_NAME) doctor

console: ## Open bench console
	@cd $(COMPOSE_DIR) && docker compose exec backend bench --site $(SITE_NAME) console

backend-shell: ## Open a shell in the backend container
	@cd $(COMPOSE_DIR) && docker compose exec backend bash

# ---------- Backup & Restore ----------

backup: ## Run backup script
	@bash scripts/backup.sh

restore: ## Restore site from a backup file (usage: make restore FILE=/path/to/database.sql.gz)
	@if [ -z "$(FILE)" ]; then echo "Usage: make restore FILE=/path/to/database.sql.gz"; exit 1; fi
	@cd $(COMPOSE_DIR) && docker compose exec -T backend bench --force --site $(SITE_NAME) restore $(FILE)

# ---------- Monitoring ----------

monitor: ## Show system status summary
	@bash scripts/monitor.sh

health: ## Quick health check
	@cd $(COMPOSE_DIR) && docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost/ || echo "Frontend unreachable"

# ---------- Maintenance ----------

update: ## Pull latest images and recreate containers
	@cd $(COMPOSE_DIR) && docker compose pull
	@cd $(COMPOSE_DIR) && docker compose up -d --remove-orphans

prune: ## Clean unused Docker resources
	@docker system prune -f --volumes

# ---------- LXC (PVE) ----------

lxc-check: ## Check if AppArmor is available (LXC issue)
	@if cat /sys/kernel/security/apparmor/enabled 2>/dev/null | grep -q 1; then \
		echo "AppArmor is ENABLED (no LXC workaround needed)"; \
	else \
		echo "AppArmor is DISABLED (LXC workaround needed — use compose.lxc.yaml)"; \
	fi
